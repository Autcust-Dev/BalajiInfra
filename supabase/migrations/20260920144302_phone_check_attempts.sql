-- Rate-limit ledger for the check-phone Edge Function (CLAUDE.md §4 rule 31: per-IP and
-- per-phone rate limiting before an OTP is sent). No anon/authenticated grants at all —
-- only service_role (the check-phone Edge Function) ever touches it, same pattern as
-- webhook_events.
create table public.phone_check_attempts (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  ip inet not null,
  created_at timestamptz not null default now()
);

alter table public.phone_check_attempts enable row level security;

-- No grants to anon/authenticated (CLAUDE.md §4 rule 9 addendum). RLS is enabled with zero
-- policies as a second layer of defense. service_role's BYPASSRLS attribute skips RLS but
-- NOT the base table privilege system, so it still needs its own explicit grant here.
grant select, insert, delete on public.phone_check_attempts to service_role;

-- check-phone deletes rows older than its rate-limit window on every call instead of
-- relying on a cron job, so this stays index-only rather than needing pg_cron this phase.
create index phone_check_attempts_phone_created_at_idx
  on public.phone_check_attempts (phone, created_at);
create index phone_check_attempts_ip_created_at_idx
  on public.phone_check_attempts (ip, created_at);
