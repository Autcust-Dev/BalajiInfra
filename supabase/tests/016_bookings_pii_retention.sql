begin;
select plan(4);

-- delete_abandoned_bookings() is security definer, callable regardless of role, but we
-- drive the setup as the owner admin (full access to bookings) for clarity.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- A paid booking, old enough to otherwise qualify, with a tenant already created from it —
-- must survive: it's a financial record, protected on two independent grounds (paid status
-- AND created_tenant_id set).
insert into public.bookings (
  id, property_id, room_unit_id, bed_id, full_name, phone, status, billing_cycle,
  security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
  held_expires_at, created_tenant_id, created_at
)
select
  'f0000001-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
  'b4444444-4444-4444-4444-444444444444', id, 'Old Paid Tenant', '+919876520001', 'paid', 'monthly',
  500000, 800000, 100000, 1400000, now() - interval '200 days',
  '66666666-6666-6666-6666-666666666666', now() - interval '200 days'
from public.beds where room_unit_id = 'b5555555-5555-5555-5555-555555555555' and bed_label = 'Bed 1';

-- A refunded booking, old, with no linked tenant (e.g. refunded before a tenant was ever
-- created) — must also survive: refunded is independently protected.
insert into public.bookings (
  id, property_id, room_unit_id, bed_id, full_name, phone, status, billing_cycle,
  security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
  held_expires_at, created_at
)
select
  'f0000002-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333',
  'b4444444-4444-4444-4444-444444444444', id, 'Old Refunded', '+919876520002', 'refunded', 'monthly',
  500000, 800000, 100000, 1400000, now() - interval '200 days', now() - interval '200 days'
from public.beds where room_unit_id = 'b5555555-5555-5555-5555-555555555555' and bed_label = 'Bed 2';

-- An old, genuinely abandoned booking (expired, never became a tenant) — must be deleted.
insert into public.bookings (
  id, property_id, room_unit_id, bed_id, full_name, phone, status, billing_cycle,
  security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
  held_expires_at, created_at
)
select
  'f0000003-0000-0000-0000-000000000003', '99999999-9999-9999-9999-999999999999',
  'be000000-0000-0000-0000-000000000000', id, 'Old Abandoned', '+919876520003', 'expired', 'monthly',
  500000, 800000, 100000, 1400000, now() - interval '200 days', now() - interval '200 days'
from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 1';

-- A recent, abandoned booking (within the retention window) — must survive for now.
insert into public.bookings (
  id, property_id, room_unit_id, bed_id, full_name, phone, status, billing_cycle,
  security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
  held_expires_at, created_at
)
select
  'f0000004-0000-0000-0000-000000000004', '99999999-9999-9999-9999-999999999999',
  'be000000-0000-0000-0000-000000000000', id, 'Recent Abandoned', '+919876520004', 'cancelled', 'monthly',
  500000, 800000, 100000, 1400000, now() - interval '1 day', now() - interval '1 day'
from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 2';

select public.delete_abandoned_bookings();

select isnt_empty(
  $$ select * from public.bookings where id = 'f0000001-0000-0000-0000-000000000001' $$,
  'an old paid booking (financial record) survives the sweep'
);
select isnt_empty(
  $$ select * from public.bookings where id = 'f0000002-0000-0000-0000-000000000002' $$,
  'an old refunded booking (financial record) survives the sweep'
);
select is_empty(
  $$ select * from public.bookings where id = 'f0000003-0000-0000-0000-000000000003' $$,
  'an old abandoned booking that never became a tenant is deleted'
);
select isnt_empty(
  $$ select * from public.bookings where id = 'f0000004-0000-0000-0000-000000000004' $$,
  'a recently abandoned booking survives — not old enough yet'
);

select * from finish();
rollback;
