-- Admin enters one electricity bill per room per calendar month; it's split evenly across
-- that room's active tenants, and each tenant's share becomes a `dues` row (type =
-- 'electricity') they can see and pay like any other due.
create table public.electricity_bills (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id),
  billing_period date not null, -- always the 1st of the month, e.g. 2026-09-01
  total_amount_paise bigint not null check (total_amount_paise > 0),
  created_by uuid not null references public.admins (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_id, billing_period)
);

-- Pure junction table: the amount owed lives solely on the linked `dues` row (rule 6 money
-- handling already applies there), not duplicated here — a second amount column would just
-- be another way for the two to silently disagree.
create table public.electricity_bill_splits (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.electricity_bills (id) on delete cascade,
  tenant_id uuid not null references public.tenants (id),
  due_id uuid not null references public.dues (id),
  created_at timestamptz not null default now(),
  unique (bill_id, tenant_id),
  unique (due_id)
);

alter table public.electricity_bills enable row level security;
alter table public.electricity_bill_splits enable row level security;

grant select, insert, update on public.electricity_bills to authenticated;
grant select, insert, update on public.electricity_bills to service_role;
-- No DELETE grant to anyone (same convention as `dues`): correcting a mistaken bill means
-- editing total_amount_paise (which re-triggers the split below) or editing an individual
-- tenant's due, not deleting the bill outright — deleting it would either cascade-orphan
-- the linked dues or leave them stranded with no bill to explain them.
grant select, insert on public.electricity_bill_splits to authenticated;
grant select, insert on public.electricity_bill_splits to service_role;

create policy "admin full access" on public.electricity_bills
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "approved tenant reads own room's bills" on public.electricity_bills
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and room_id = (select t.room_id from public.tenants t where t.id = public.current_tenant_id())
  );

create policy "admin full access" on public.electricity_bill_splits
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "tenant reads own splits" on public.electricity_bill_splits
  for select
  to authenticated
  using (public.is_tenant() and tenant_id = public.current_tenant_id() and public.tenant_can_access_main_app());

create trigger set_updated_at
  before update on public.electricity_bills
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.electricity_bills
  for each row
  execute function public.audit_log_row();

create trigger audit_log_row
  after insert or update or delete on public.electricity_bill_splits
  for each row
  execute function public.audit_log_row();

-- The actual splitting logic. Re-runs safely any number of times for the same bill
-- (idempotent): recomputes from the bill's current total and the room's current tenants,
-- so "recalculate" is just "call this again."
--
-- A split is FROZEN (excluded from redistribution, amount never touched) once either:
--   - its due has been paid, or
--   - its tenant has moved out (rule: a due stays against a moved-out tenant — they can't
--     leave owing nothing, and the room's remaining/new tenants pick up the rest).
-- Everything else (active tenants with an unpaid due, including ones with no split yet) is
-- redistributed evenly over `total_amount_paise - frozen_total`, remainder handled
-- deterministically: floor-divide, then hand the leftover paise one at a time to tenants
-- ordered by move_in_date (earliest first), then id as a tiebreaker. This only matters when
-- the total doesn't divide evenly — admins can freely hand-edit any unpaid tenant's due
-- afterward regardless of how the remainder landed.
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
  where t.room_id = v_bill.room_id
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

create or replace function public.trigger_recalculate_electricity_bill()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.recalculate_electricity_bill_split(new.id);
  return new;
end;
$$;

-- Splits automatically on bill creation, and again if the admin corrects the total.
create trigger recalculate_on_insert
  after insert on public.electricity_bills
  for each row
  execute function public.trigger_recalculate_electricity_bill();

create trigger recalculate_on_total_change
  after update of total_amount_paise on public.electricity_bills
  for each row
  execute function public.trigger_recalculate_electricity_bill();

-- Recalculates automatically when room occupancy changes (a tenant joins, moves out, or
-- switches rooms) — "the sharing will start automatically with new roommate."
create or replace function public.recalculate_room_electricity_bills_on_tenant_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bill_id uuid;
begin
  if TG_OP = 'UPDATE' and old.status = new.status and old.room_id = new.room_id then
    return new;
  end if;

  for v_bill_id in select id from public.electricity_bills where room_id = new.room_id loop
    perform public.recalculate_electricity_bill_split(v_bill_id);
  end loop;

  if TG_OP = 'UPDATE' and old.room_id is distinct from new.room_id then
    for v_bill_id in select id from public.electricity_bills where room_id = old.room_id loop
      perform public.recalculate_electricity_bill_split(v_bill_id);
    end loop;
  end if;

  return new;
end;
$$;

create trigger recalculate_electricity_bills
  after insert or update of status, room_id on public.tenants
  for each row
  execute function public.recalculate_room_electricity_bills_on_tenant_change();
