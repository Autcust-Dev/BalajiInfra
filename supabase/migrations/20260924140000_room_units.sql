-- A physical room (e.g. "S1") can itself hold multiple independently-billed sharing
-- units: a single-sharing bed, a double-sharing bed, a triple-sharing bed, any subset of
-- them, never more than one of a given sharing type. Each unit is its own occupancy group
-- and its own electricity-bill split — a single-sharing unit's tenant never splits with
-- anyone (there's only ever one tenant in it), a double-sharing unit splits between its two,
-- and so on. `rooms` becomes a pure location shell (number, floor/block); `capacity` and the
-- tenant/bill linkage move down to `room_units`.
create table public.room_units (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  capacity integer not null check (capacity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_id, capacity)
);

alter table public.room_units enable row level security;

grant select, insert, update, delete on public.room_units to authenticated;
grant select, insert, update, delete on public.room_units to service_role;

create policy "admin full access" on public.room_units
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- The tenant-facing "reads own unit" policy is added further down, once
-- tenants.room_unit_id exists (a CREATE POLICY's USING clause is validated against the
-- catalog immediately, so it can't forward-reference a column that isn't there yet).

create trigger set_updated_at
  before update on public.room_units
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.room_units
  for each row
  execute function public.audit_log_row();

-- Backfill: one unit per existing room, carrying over that room's current capacity, so
-- every already-assigned tenant keeps the same occupancy group they're in today. On a
-- fresh database (migrations run before seed.sql) `rooms` is empty here and this is a
-- no-op — seed.sql inserts room_units directly instead.
insert into public.room_units (room_id, capacity)
select id, capacity from public.rooms;

alter table public.tenants add column room_unit_id uuid references public.room_units (id);

update public.tenants t
set room_unit_id = ru.id
from public.room_units ru
where ru.room_id = t.room_id;

alter table public.tenants alter column room_unit_id set not null;

create policy "approved tenant reads own unit" on public.room_units
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (
      select t.room_unit_id from public.tenants t where t.id = public.current_tenant_id()
    )
  );

-- Drop and recreate every policy/trigger that reads tenants.room_id before dropping the
-- column — Postgres tracks these as dependencies (like a view or check constraint would),
-- so the column can't be dropped while they still reference it.
drop policy "approved tenant reads own room" on public.rooms;
create policy "approved tenant reads own room" on public.rooms
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (
      select ru.room_id
      from public.tenants t
      join public.room_units ru on ru.id = t.room_unit_id
      where t.id = public.current_tenant_id()
    )
  );

drop policy "approved tenant reads own floor" on public.floors;
create policy "approved tenant reads own floor" on public.floors
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (
      select b.floor_id
      from public.tenants t
      join public.room_units ru on ru.id = t.room_unit_id
      join public.rooms r on r.id = ru.room_id
      join public.blocks b on b.id = r.block_id
      where t.id = public.current_tenant_id()
    )
  );

drop policy "approved tenant reads own block" on public.blocks;
create policy "approved tenant reads own block" on public.blocks
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (
      select r.block_id
      from public.tenants t
      join public.room_units ru on ru.id = t.room_unit_id
      join public.rooms r on r.id = ru.room_id
      where t.id = public.current_tenant_id()
    )
  );

-- electricity_bills/electricity_bill_splits move from room_id to room_unit_id the same way,
-- done here (before dropping tenants.room_id) since this policy's subquery also depends on it.
alter table public.electricity_bills add column room_unit_id uuid references public.room_units (id);

update public.electricity_bills eb
set room_unit_id = ru.id
from public.room_units ru
where ru.room_id = eb.room_id;

alter table public.electricity_bills alter column room_unit_id set not null;

alter table public.electricity_bills drop constraint electricity_bills_room_id_billing_period_key;
alter table public.electricity_bills add constraint electricity_bills_room_unit_id_billing_period_key
  unique (room_unit_id, billing_period);

drop policy "approved tenant reads own room's bills" on public.electricity_bills;
create policy "approved tenant reads own room's bills" on public.electricity_bills
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and room_unit_id = (
      select t.room_unit_id from public.tenants t where t.id = public.current_tenant_id()
    )
  );

-- This trigger's column list ("of status, room_id") depends on tenants.room_id — drop it
-- now, recreated further down against room_unit_id once the split functions are updated.
drop trigger recalculate_electricity_bills on public.tenants;

-- Re-declare the tenant self-update guard (see the comment on this pattern in
-- add_tenant_move_out_date.sql) to protect room_unit_id instead of the now-dropped room_id.
create or replace function public.tenants_tenant_update_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if old.property_id is distinct from new.property_id
    or old.room_unit_id is distinct from new.room_unit_id
    or old.full_name is distinct from new.full_name
    or old.phone is distinct from new.phone
    or old.firebase_uid is distinct from new.firebase_uid
    or old.status is distinct from new.status
    or old.kyc_status is distinct from new.kyc_status
    or old.move_in_date is distinct from new.move_in_date
    or old.move_out_date is distinct from new.move_out_date
    or old.monthly_rent_paise is distinct from new.monthly_rent_paise
    or old.billing_cycle is distinct from new.billing_cycle
  then
    raise exception 'tenants: only fcm_token may be updated by a tenant';
  end if;

  return new;
end;
$$;

alter table public.tenants drop column room_id;
alter table public.rooms drop column capacity;
alter table public.electricity_bills drop column room_id;

create or replace function public.recalculate_electricity_bill_split(p_bill_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill public.electricity_bills;
  v_frozen_total bigint;
  v_pool bigint;
  v_tenant_ids uuid[];
  v_count integer;
  v_base bigint;
  v_remainder bigint;
  v_idx integer := 0;
  v_tenant_id uuid;
  v_amount bigint;
  v_due_id uuid;
begin
  select * into v_bill from public.electricity_bills where id = p_bill_id;
  if not found then
    return;
  end if;

  select coalesce(sum(d.amount_paise), 0) into v_frozen_total
  from public.electricity_bill_splits s
  join public.dues d on d.id = s.due_id
  join public.tenants t on t.id = s.tenant_id
  where s.bill_id = p_bill_id
    and (d.status = 'paid' or t.status = 'moved_out');

  v_pool := greatest(v_bill.total_amount_paise - v_frozen_total, 0);

  select array_agg(t.id order by t.move_in_date asc, t.id asc) into v_tenant_ids
  from public.tenants t
  where t.room_unit_id = v_bill.room_unit_id
    and t.status = 'active'
    and not exists (
      select 1
      from public.electricity_bill_splits s2
      join public.dues d2 on d2.id = s2.due_id
      where s2.bill_id = p_bill_id and s2.tenant_id = t.id and d2.status = 'paid'
    );

  v_count := coalesce(array_length(v_tenant_ids, 1), 0);
  if v_count = 0 or v_pool = 0 then
    return;
  end if;

  v_base := v_pool / v_count;
  v_remainder := v_pool % v_count;

  foreach v_tenant_id in array v_tenant_ids loop
    v_idx := v_idx + 1;
    v_amount := v_base + (case when v_idx <= v_remainder then 1 else 0 end);
    continue when v_amount <= 0;

    select due_id into v_due_id
    from public.electricity_bill_splits
    where bill_id = p_bill_id and tenant_id = v_tenant_id;

    if v_due_id is null then
      insert into public.dues (tenant_id, type, description, amount_paise, due_date, status, created_by)
      values (
        v_tenant_id,
        'electricity',
        'Electricity — ' || to_char(v_bill.billing_period, 'Mon YYYY'),
        v_amount,
        (v_bill.billing_period + interval '1 month' - interval '1 day')::date,
        'unpaid',
        v_bill.created_by
      )
      returning id into v_due_id;

      insert into public.electricity_bill_splits (bill_id, tenant_id, due_id)
      values (p_bill_id, v_tenant_id, v_due_id);
    else
      update public.dues set amount_paise = v_amount where id = v_due_id and status <> 'paid';
    end if;
  end loop;
end;
$$;

create or replace function public.recalculate_room_electricity_bills_on_tenant_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill_id uuid;
begin
  if TG_OP = 'UPDATE' and old.status = new.status and old.room_unit_id = new.room_unit_id then
    return new;
  end if;

  for v_bill_id in select id from public.electricity_bills where room_unit_id = new.room_unit_id loop
    perform public.recalculate_electricity_bill_split(v_bill_id);
  end loop;

  if TG_OP = 'UPDATE' and old.room_unit_id is distinct from new.room_unit_id then
    for v_bill_id in select id from public.electricity_bills where room_unit_id = old.room_unit_id loop
      perform public.recalculate_electricity_bill_split(v_bill_id);
    end loop;
  end if;

  return new;
end;
$$;

create trigger recalculate_electricity_bills
  after insert or update of status, room_unit_id on public.tenants
  for each row
  execute function public.recalculate_room_electricity_bills_on_tenant_change();
