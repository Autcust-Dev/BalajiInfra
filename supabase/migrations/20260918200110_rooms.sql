-- Owner + staff manage rooms (CLAUDE.md Phase 1 addition). An approved, active tenant may
-- also read their own room only (CLAUDE.md Phase 1 addition, refined), never any other room.
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  room_number text not null,
  capacity integer not null check (capacity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, room_number)
);

alter table public.rooms enable row level security;

grant select, insert, update, delete on public.rooms to authenticated;
grant select, insert, update, delete on public.rooms to service_role;

create policy "admin full access" on public.rooms
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- The tenant-facing "reads own room only" policy lives in a later migration
-- (tenant_room_property_access.sql), for the same reason as the equivalent note in
-- properties.sql.

create trigger set_updated_at
  before update on public.rooms
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.rooms
  for each row
  execute function public.audit_log_row();
