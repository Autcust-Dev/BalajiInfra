-- Publicly readable config the app checks before/without login (e.g. min_app_version),
-- per CLAUDE.md §4 rule 30. Readable by anon and authenticated; writable only by owners
-- (CLAUDE.md Phase 1 addition) — this is a narrower read grant than the rest of the
-- owner-only tier (admins/properties), carved out explicitly because the app needs it
-- pre-login.
create table public.app_config (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  value jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

grant select on public.app_config to anon, authenticated;
grant insert, update, delete on public.app_config to authenticated;

create policy "anyone reads config" on public.app_config
  for select
  to anon, authenticated
  using (true);

create policy "owner writes config" on public.app_config
  for insert
  to authenticated
  with check (public.is_owner());

create policy "owner updates config" on public.app_config
  for update
  to authenticated
  using (public.is_owner())
  with check (public.is_owner());

create policy "owner deletes config" on public.app_config
  for delete
  to authenticated
  using (public.is_owner());

create trigger set_updated_at
  before update on public.app_config
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.app_config
  for each row
  execute function public.audit_log_row();
