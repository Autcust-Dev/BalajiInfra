-- Owner manages fully; staff gets read-only access (CLAUDE.md Phase 1 addition, refined).
-- An approved, active tenant may also read their own property only, never any other
-- property (policy added in tenant_room_property_access.sql, once tenants exists).
create table public.properties (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.properties enable row level security;

grant select, insert, update, delete on public.properties to authenticated;
grant select, insert, update, delete on public.properties to service_role;

create policy "owner full access" on public.properties
  for all
  to authenticated
  using (public.is_owner())
  with check (public.is_owner());

create policy "staff reads all properties" on public.properties
  for select
  to authenticated
  using (public.is_admin());

-- The tenant-facing "reads own property only" policy lives in a later migration
-- (tenant_room_property_access.sql): a CREATE POLICY's USING clause is validated against
-- the catalog immediately (unlike a plpgsql function body), so it can't reference
-- public.tenants before that table exists.

create trigger set_updated_at
  before update on public.properties
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.properties
  for each row
  execute function public.audit_log_row();
