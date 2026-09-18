-- Owner + staff manage rooms (CLAUDE.md Phase 1 addition). No tenant-facing access yet —
-- the app doesn't need it until a later phase surfaces room details to tenants.
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

create policy "admin full access" on public.rooms
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create trigger set_updated_at
  before update on public.rooms
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.rooms
  for each row
  execute function public.audit_log_row();
