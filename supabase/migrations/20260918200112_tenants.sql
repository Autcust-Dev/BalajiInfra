create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id),
  room_id uuid not null references public.rooms (id),
  full_name text not null,
  -- Literal "+91 followed by 10 digits" per the approved Phase 1 scope.
  phone text not null unique check (phone ~ '^\+91[0-9]{10}$'),
  firebase_uid text unique,
  status public.tenant_status not null default 'active',
  kyc_status public.kyc_status not null default 'not_started',
  move_in_date date not null,
  monthly_rent_paise bigint not null check (monthly_rent_paise > 0),
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.tenants enable row level security;

grant select, insert, update, delete on public.tenants to authenticated;

create policy "admin full access" on public.tenants
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Tenants read only their own row, and only while not moved out (CLAUDE.md Phase 1
-- addition: "Tenants with status moved_out get no access at all").
create policy "tenant reads own row" on public.tenants
  for select
  to authenticated
  using (public.is_tenant() and id = public.current_tenant_id() and status <> 'moved_out');

-- Tenants may update their own row, but the trigger below restricts *which* columns —
-- GRANT can't do this because admins and tenants share the same Postgres `authenticated`
-- role, so a column-level GRANT would cap admins too.
create policy "tenant updates own row" on public.tenants
  for update
  to authenticated
  using (public.is_tenant() and id = public.current_tenant_id() and status <> 'moved_out')
  with check (public.is_tenant() and id = public.current_tenant_id());

-- Restricts a tenant-initiated UPDATE to the fcm_token column only. Admins (is_admin())
-- pass through unrestricted, as does anything not running as the plain `authenticated`
-- Postgres role — e.g. the security-definer KYC-status sync trigger (which updates
-- kyc_status from kyc_submissions) or service_role from an Edge Function. Only a literal
-- PostgREST request authenticated as a tenant is restricted. Update the compared column
-- list below if tenants gains new columns.
create or replace function public.tenants_tenant_update_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if old.property_id is distinct from new.property_id
    or old.room_id is distinct from new.room_id
    or old.full_name is distinct from new.full_name
    or old.phone is distinct from new.phone
    or old.firebase_uid is distinct from new.firebase_uid
    or old.status is distinct from new.status
    or old.kyc_status is distinct from new.kyc_status
    or old.move_in_date is distinct from new.move_in_date
    or old.monthly_rent_paise is distinct from new.monthly_rent_paise
  then
    raise exception 'tenants: only fcm_token may be updated by a tenant';
  end if;

  return new;
end;
$$;

create trigger tenant_update_guard
  before update on public.tenants
  for each row
  execute function public.tenants_tenant_update_guard();

create trigger set_updated_at
  before update on public.tenants
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.tenants
  for each row
  execute function public.audit_log_row();
