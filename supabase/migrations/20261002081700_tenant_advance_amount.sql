-- "Advance" — an amount collected from the tenant up front (distinct from monthly_rent_paise
-- and distinct from a security-deposit `due`, which is its own dues/payments row with a full
-- audit trail). Deliberately a single plain field, not its own table: there's no requirement
-- yet for advance history/refund tracking, matching this codebase's existing "start simple"
-- treatment of fields that don't need a ledger (e.g. fines before they needed one). If advance
-- refunds or partial-adjustment history is ever needed, that's an additive follow-up, not a
-- rework of this column.
alter table public.tenants add column advance_paise bigint not null default 0 check (advance_paise >= 0);

-- Re-declare the tenant self-update guard (see the comment on this pattern in
-- add_tenant_move_out_date.sql) to also protect advance_paise from a tenant-initiated update.
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
    or old.room_unit_id is distinct from new.room_unit_id
    or old.bed_id is distinct from new.bed_id
    or old.full_name is distinct from new.full_name
    or old.phone is distinct from new.phone
    or old.firebase_uid is distinct from new.firebase_uid
    or old.status is distinct from new.status
    or old.kyc_status is distinct from new.kyc_status
    or old.move_in_date is distinct from new.move_in_date
    or old.move_out_date is distinct from new.move_out_date
    or old.monthly_rent_paise is distinct from new.monthly_rent_paise
    or old.billing_cycle is distinct from new.billing_cycle
    or old.advance_paise is distinct from new.advance_paise
  then
    raise exception 'tenants: only fcm_token may be updated by a tenant';
  end if;

  return new;
end;
$$;
