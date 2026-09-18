-- Owner-only table (CLAUDE.md Phase 1 addition: "only owner can manage admins, properties
-- and app_config"). Staff manages rooms/tenants which reference properties by id, but has
-- no direct read/write access to this table.
create table public.properties (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.properties enable row level security;

grant select, insert, update, delete on public.properties to authenticated;

create policy "owner full access" on public.properties
  for all
  to authenticated
  using (public.is_owner())
  with check (public.is_owner());

create trigger set_updated_at
  before update on public.properties
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.properties
  for each row
  execute function public.audit_log_row();
