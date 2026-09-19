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
grant select, insert, update, delete on public.app_config to service_role;

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

-- Single source of truth for the Firebase project id used by is_tenant()'s iss/aud check
-- (CLAUDE.md §4 rule 13; see also the comment on is_tenant() in helper_functions.sql).
-- Deliberately app_config, not a hardcoded value in any function: changing environments
-- (local vs hosted) means changing this one row, not editing SQL.
--
-- Starts as JSON null: fail-closed. Until this is set to a real project id, is_tenant()
-- returns false for everyone, so Firebase tenant auth simply doesn't work rather than
-- silently trusting an unconfigured/wrong issuer.
--
--   Local dev / tests: supabase/seed.sql overwrites this with a fake placeholder value
--   (seed.sql only ever runs locally — never against the hosted database).
--
--   Hosted: a human sets the real value once the Firebase project exists (CLAUDE.md §8,
--   "Tasks only the human can do" — Firebase project creation), via the Studio SQL editor
--   or an authenticated request, e.g.:
--     update public.app_config set value = '"<real-firebase-project-id>"'::jsonb
--     where key = 'firebase_project_id';
--   This is a data change, not a migration — it must never be pushed as a migration, since
--   the same migration would overwrite the hosted value back to null on every deploy.
--
-- Defined before the insert below: that insert fires the audit_log_row trigger, which
-- calls is_tenant(), which calls this function — it must already exist by execution time,
-- not just by the time the whole migration finishes.
create or replace function public._firebase_project_id()
returns text
language sql
security definer
stable
set search_path = ''
as $$
  select value #>> '{}' from public.app_config where key = 'firebase_project_id';
$$;

insert into public.app_config (key, value) values ('firebase_project_id', 'null'::jsonb);
