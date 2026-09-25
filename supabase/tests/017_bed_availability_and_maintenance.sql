begin;
select plan(14);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- Seed backfilled Bed 1/Bed 2 of room_unit b4444444 to the two active tenants there.
select is(
  (select bed_id from public.tenants where id = '66666666-6666-6666-6666-666666666666'),
  (select id from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1'),
  'seed backfill assigned Bed 1 to the first active tenant by move_in_date'
);
select is(
  (select bed_id from public.tenants where id = 'f2222222-2222-2222-2222-222222222222'),
  (select id from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 2'),
  'seed backfill assigned Bed 2 to the second active tenant'
);

-- bed_is_available() reflects tenant occupancy, not just bookings.
select ok(
  not public.bed_is_available(
    (select id from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1')
  ),
  'a bed occupied by an active tenant is not available'
);

-- An unoccupied bed elsewhere is available.
select ok(
  public.bed_is_available(
    (select id from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 1')
  ),
  'an unoccupied bed with no holds is available'
);

-- At most one active tenant per bed.
select throws_ok(
  $$ update public.tenants set bed_id = (
       select id from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1'
     )
     where id = 'f2222222-2222-2222-2222-222222222222' $$,
  '23505',
  null,
  'a second active tenant cannot be assigned a bed another active tenant already occupies'
);

-- bed_id must belong to the tenant's own room_unit_id.
select throws_ok(
  $$ update public.tenants set bed_id = (
       select id from public.beds where room_unit_id = 'b5555555-5555-5555-5555-555555555555' and bed_label = 'Bed 2'
     )
     where id = '66666666-6666-6666-6666-666666666666' $$,
  'P0001',
  'tenants: bed_id does not belong to the tenant''s room_unit_id',
  'a bed from a different room_unit cannot be assigned to a tenant'
);

-- Marking a bed under maintenance flips availability off, even with no tenant or booking.
update public.beds set under_maintenance = true
where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 1';
select ok(
  not public.bed_is_available(
    (select id from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 1')
  ),
  'a bed under maintenance is not available'
);

-- A booking cannot hold a bed under maintenance.
select throws_ok(
  $$ insert into public.bookings (
       property_id, room_unit_id, bed_id, phone, billing_cycle,
       security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
       held_expires_at
     )
     select '99999999-9999-9999-9999-999999999999', 'be000000-0000-0000-0000-000000000000', id,
       '+919876533333', 'monthly', 500000, 800000, 100000, 1400000, now() + interval '10 minutes'
     from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 1' $$,
  'P0001',
  'bookings: cannot hold a bed that is under maintenance',
  'a booking cannot be placed on a bed under maintenance'
);

-- An active tenant cannot be assigned a bed under maintenance either.
select throws_ok(
  $$ update public.tenants set bed_id = (
       select id from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 1'
     ), room_unit_id = 'be000000-0000-0000-0000-000000000000', property_id = '99999999-9999-9999-9999-999999999999'
     where id = '77777777-7777-7777-7777-777777777777' $$,
  'P0001',
  'tenants: cannot assign a bed that is under maintenance',
  'an active tenant cannot be assigned a bed under maintenance'
);

-- A live (unexpired) hold makes a bed unavailable too, same as tenant occupancy.
insert into public.bookings (
  property_id, room_unit_id, bed_id, phone, billing_cycle,
  security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
  held_expires_at
)
select '99999999-9999-9999-9999-999999999999', 'be000000-0000-0000-0000-000000000000', id,
  '+919876544444', 'monthly', 500000, 800000, 100000, 1400000, now() + interval '10 minutes'
from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 2';

select ok(
  not public.bed_is_available(
    (select id from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 2')
  ),
  'a bed with a live hold is not available'
);

-- Once the hold expires (in the past), the bed is available again.
update public.bookings set held_expires_at = now() - interval '1 minute'
where bed_id = (select id from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 2');

select ok(
  public.bed_is_available(
    (select id from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 2')
  ),
  'a bed with only an expired hold is available again (lazy expiry)'
);

-- The room_unit-level headcount safety net for tenants with no bed_id (see the comment on
-- bed_is_available()): b5555555 has capacity 2, with one active tenant properly on Bed 1
-- and Bed 2 genuinely free — baseline is available.
select ok(
  public.bed_is_available(
    (select id from public.beds where room_unit_id = 'b5555555-5555-5555-5555-555555555555' and bed_label = 'Bed 2')
  ),
  'baseline: an unoccupied bed in a room with one (of two) active tenants is available'
);

-- A second active tenant with no bed_id fills the room to capacity without pointing at
-- any specific bed.
insert into public.tenants (property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
values ('33333333-3333-3333-3333-333333333333', 'b5555555-5555-5555-5555-555555555555', 'Untracked Occupant', '+919876555555', 'active', 'not_started', current_date, 1000000);

select ok(
  not public.bed_is_available(
    (select id from public.beds where room_unit_id = 'b5555555-5555-5555-5555-555555555555' and bed_label = 'Bed 2')
  ),
  'an untracked (bed_id null) active tenant fills the room to capacity, so its other bed is no longer offered even though nothing points at it directly'
);

-- The headcount check is scoped per room_unit — an unrelated, genuinely free bed
-- elsewhere is unaffected (be000000's Bed 1 is under maintenance from earlier in this
-- file, so Bed 2 — freed a moment ago by the expired-hold check above — is the clean one
-- to use here).
select ok(
  public.bed_is_available(
    (select id from public.beds where room_unit_id = 'be000000-0000-0000-0000-000000000000' and bed_label = 'Bed 2')
  ),
  'a free bed in an unrelated room_unit is unaffected by another room''s untracked occupant'
);

select * from finish();
rollback;
