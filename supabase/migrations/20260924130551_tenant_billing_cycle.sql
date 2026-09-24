-- Monthly or yearly package (yearly = monthly_rent_paise * 12, charged as one due at
-- joining, no discount — confirmed with the client). No renewal automation: after year
-- one, an admin can optionally create a fresh due whenever they choose; nothing in the
-- system forces or schedules it.
create type public.billing_cycle as enum ('monthly', 'yearly');

alter table public.tenants add column billing_cycle public.billing_cycle not null default 'monthly';

-- Re-declare the tenant self-update guard (see the comment on this pattern in
-- 20260919122050_add_tenant_move_out_date.sql) to also protect billing_cycle from a
-- tenant-initiated update.
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
    or old.billing_cycle is distinct from new.billing_cycle
  then
    raise exception 'tenants: only fcm_token may be updated by a tenant';
  end if;

  return new;
end;
$$;
