-- Owner manages admins fully; staff may only read their own row (CLAUDE.md Phase 1
-- addition, refined: "staff read-only access to their own admins row"). Bootstrapping the
-- first owner happens manually via SQL/seed, never self-signup (CLAUDE.md §4 rule 15).
create table public.admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  name text not null,
  role public.admin_role not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.admins enable row level security;

grant select, insert, update, delete on public.admins to authenticated;
-- Trusted backend role (Edge Functions only, gated by the service key itself) — RLS is
-- bypassed for service_role, but base table privileges are not, so it still needs an
-- explicit grant (CLAUDE.md Phase 1 addition: confirmed service_role otherwise has zero
-- working access despite BYPASSRLS).
grant select, insert, update, delete on public.admins to service_role;

create policy "owner full access" on public.admins
  for all
  to authenticated
  using (public.is_owner())
  with check (public.is_owner());

create policy "staff reads own row" on public.admins
  for select
  to authenticated
  using (public.is_admin() and user_id = public._jwt_sub_as_uuid());

create trigger set_updated_at
  before update on public.admins
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.admins
  for each row
  execute function public.audit_log_row();
