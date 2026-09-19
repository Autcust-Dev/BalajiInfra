-- Idempotency ledger for payment webhooks (CLAUDE.md §4 rule 26). No anon/authenticated
-- grants at all — only service_role (the razorpay-webhook Edge Function) ever touches it.
create table public.webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_id text not null,
  payload jsonb not null,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, event_id)
);

alter table public.webhook_events enable row level security;

-- No grants to anon/authenticated (CLAUDE.md §4 rule 9 addendum). RLS is enabled with zero
-- policies as a second layer of defense. service_role's BYPASSRLS attribute skips RLS but
-- NOT the base table privilege system, so it still needs its own explicit grant here —
-- without it, the razorpay-webhook Edge Function has no access to this table at all.
grant select, insert, update on public.webhook_events to service_role;

create trigger set_updated_at
  before update on public.webhook_events
  for each row
  execute function public.set_updated_at();
