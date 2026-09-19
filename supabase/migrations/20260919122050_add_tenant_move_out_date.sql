-- Additive column for the admin panel's move-out action (CLAUDE.md §4 rule 2: additive
-- only). Nullable — only ever set when status transitions to 'moved_out'. Mirrors the
-- kyc_submissions.rejection_reason-required-when-rejected pattern from Phase 1.
alter table public.tenants add column move_out_date date;

alter table public.tenants add constraint tenants_move_out_date_required_when_moved_out
  check (status <> 'moved_out' or move_out_date is not null);

-- Re-declare the tenant self-update guard (originally in
-- 20260918200112_tenants.sql, already applied to the hosted database — that file is never
-- edited after the fact) to also forbid a tenant from touching move_out_date themselves.
-- Only admins (or service_role/other elevated callers — see the original migration's
-- comment) may set it, via the move-out action.
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
    or old.move_out_date is distinct from new.move_out_date
    or old.monthly_rent_paise is distinct from new.monthly_rent_paise
  then
    raise exception 'tenants: only fcm_token may be updated by a tenant';
  end if;

  return new;
end;
$$;
