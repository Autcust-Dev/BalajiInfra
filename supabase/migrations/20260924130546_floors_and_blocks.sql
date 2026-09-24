-- Property -> Floor -> Block -> Room. Normalized tables (not columns on rooms): the client
-- may want per-floor/block electricity meters and occupancy/collection reports later, and
-- restructuring a flattened design after real tenant data exists would be costly. Kept
-- deliberately minimal (id, parent, name, display_order) so new attributes are additive.
create table public.floors (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  name text not null,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, name)
);

create table public.blocks (
  id uuid primary key default gen_random_uuid(),
  floor_id uuid not null references public.floors (id) on delete cascade,
  name text not null,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (floor_id, name)
);

-- Nullable: existing rooms predate this hierarchy and stay valid (shown as "unassigned" in
-- the admin UI) until an admin assigns them to a block. rooms.property_id is intentionally
-- KEPT (not replaced by deriving it through block -> floor -> property) — existing Phase 2
-- code (tenant forms, room queries, RLS policies) already reads it directly, and CLAUDE.md
-- rule 2 is additive-only. The trigger below guards against the two disagreeing.
alter table public.rooms add column block_id uuid references public.blocks (id);

create or replace function public.rooms_block_matches_property()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_block_property_id uuid;
begin
  if new.block_id is null then
    return new;
  end if;

  select p.id into v_block_property_id
  from public.blocks b
  join public.floors f on f.id = b.floor_id
  join public.properties p on p.id = f.property_id
  where b.id = new.block_id;

  if v_block_property_id is distinct from new.property_id then
    raise exception 'rooms: block_id does not belong to the room''s property_id';
  end if;

  return new;
end;
$$;

create trigger block_matches_property
  before insert or update of block_id, property_id on public.rooms
  for each row
  execute function public.rooms_block_matches_property();

alter table public.floors enable row level security;
alter table public.blocks enable row level security;

grant select, insert, update, delete on public.floors to authenticated;
grant select, insert, update, delete on public.floors to service_role;
grant select, insert, update, delete on public.blocks to authenticated;
grant select, insert, update, delete on public.blocks to service_role;

create policy "admin full access" on public.floors
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "admin full access" on public.blocks
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Tenants may read only their own floor/block, mirroring the existing
-- "approved tenant reads own room/property" policies (tenant_room_property_access.sql).
-- No forward-reference issue here (unlike that migration): tenants already existed from
-- Phase 1 by the time this one runs.
create policy "approved tenant reads own floor" on public.floors
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (
      select b.floor_id
      from public.tenants t
      join public.rooms r on r.id = t.room_id
      join public.blocks b on b.id = r.block_id
      where t.id = public.current_tenant_id()
    )
  );

create policy "approved tenant reads own block" on public.blocks
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (
      select r.block_id
      from public.tenants t
      join public.rooms r on r.id = t.room_id
      where t.id = public.current_tenant_id()
    )
  );

create trigger set_updated_at
  before update on public.floors
  for each row
  execute function public.set_updated_at();

create trigger set_updated_at
  before update on public.blocks
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.floors
  for each row
  execute function public.audit_log_row();

create trigger audit_log_row
  after insert or update or delete on public.blocks
  for each row
  execute function public.audit_log_row();
