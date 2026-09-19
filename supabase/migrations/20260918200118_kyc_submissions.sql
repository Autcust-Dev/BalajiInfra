-- One row per tenant, reused across submit/reject/resubmit cycles (simplifies the
-- tenants.kyc_status sync below to a plain 1:1 mirror). A tenant may only write to this
-- row while its status is not_started (no row yet, i.e. INSERT) or rejected (UPDATE) —
-- CLAUDE.md §4 rule 20.
create table public.kyc_submissions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null unique references public.tenants (id) on delete cascade,
  status public.kyc_status not null default 'submitted',
  aadhaar_last4 text not null check (aadhaar_last4 ~ '^[0-9]{4}$'),
  aadhaar_path text not null,
  selfie_path text not null,
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references public.admins (id),
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rejection_reason_required_when_rejected
    check (status <> 'rejected' or rejection_reason is not null)
);

alter table public.kyc_submissions enable row level security;

grant select, insert, update on public.kyc_submissions to authenticated;
grant select, insert, update on public.kyc_submissions to service_role;

create policy "admin full access" on public.kyc_submissions
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Readable regardless of KYC status (CLAUDE.md Phase 1 addition), gated only on the
-- tenant not being moved out.
create policy "tenant reads own submission" on public.kyc_submissions
  for select
  to authenticated
  using (public.is_tenant() and tenant_id = public.current_tenant_id() and public.tenant_is_active());

create policy "tenant inserts own submission" on public.kyc_submissions
  for insert
  to authenticated
  with check (
    public.is_tenant()
    and tenant_id = public.current_tenant_id()
    and public.tenant_is_active()
    and status = 'submitted'
  );

create policy "tenant resubmits own submission" on public.kyc_submissions
  for update
  to authenticated
  using (public.is_tenant() and tenant_id = public.current_tenant_id() and public.tenant_is_active())
  with check (public.is_tenant() and tenant_id = public.current_tenant_id());

-- Mirrors the tenants UPDATE guard: restricts a tenant-initiated UPDATE to the
-- resubmission fields, only while the row is currently not_started/rejected, only moving
-- status forward to submitted, and never touching the review fields.
create or replace function public.kyc_submissions_tenant_update_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if old.status not in ('not_started', 'rejected') then
    raise exception 'kyc_submissions: can only be updated while not_started or rejected';
  end if;

  if new.status <> 'submitted' then
    raise exception 'kyc_submissions: a tenant may only move status to submitted';
  end if;

  if old.tenant_id is distinct from new.tenant_id
    or old.reviewed_by is distinct from new.reviewed_by
    or old.reviewed_at is distinct from new.reviewed_at
    or old.rejection_reason is distinct from new.rejection_reason
  then
    raise exception 'kyc_submissions: only aadhaar/selfie fields and status may be updated by a tenant';
  end if;

  return new;
end;
$$;

create trigger tenant_update_guard
  before update on public.kyc_submissions
  for each row
  execute function public.kyc_submissions_tenant_update_guard();

-- Keeps tenants.kyc_status mirroring this row's status. security definer + the
-- current_user bypass in tenants_tenant_update_guard let this write through even though
-- a tenant's own direct UPDATE grant on tenants is restricted to fcm_token.
create or replace function public.sync_tenant_kyc_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.tenants
  set kyc_status = new.status
  where id = new.tenant_id;

  return new;
end;
$$;

create trigger sync_tenant_kyc_status
  after insert or update on public.kyc_submissions
  for each row
  execute function public.sync_tenant_kyc_status();

create trigger set_updated_at
  before update on public.kyc_submissions
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.kyc_submissions
  for each row
  execute function public.audit_log_row();
