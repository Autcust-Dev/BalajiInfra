-- Append-only consent records (DPDP Act). No UPDATE/DELETE for anyone via the Data API —
-- once accepted, a consent record never changes (CLAUDE.md §4 rule 21).
create table public.consents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  policy_version text not null,
  typed_full_name text not null,
  accepted_at timestamptz not null default now(),
  app_version text not null,
  device_info jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.consents enable row level security;

grant select, insert on public.consents to authenticated;
grant select, insert on public.consents to service_role;

create policy "admin reads all" on public.consents
  for select
  to authenticated
  using (public.is_admin());

-- Readable/insertable pre-approval, same tier as the tenant's own row and kyc_submissions
-- (CLAUDE.md Phase 1 addition), gated only on not being moved out.
create policy "tenant reads own consents" on public.consents
  for select
  to authenticated
  using (public.is_tenant() and tenant_id = public.current_tenant_id() and public.tenant_is_active());

create policy "tenant inserts own consent" on public.consents
  for insert
  to authenticated
  with check (public.is_tenant() and tenant_id = public.current_tenant_id() and public.tenant_is_active());

create trigger set_updated_at
  before update on public.consents
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.consents
  for each row
  execute function public.audit_log_row();
