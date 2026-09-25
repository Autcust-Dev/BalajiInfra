begin;
select plan(5);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- Auto-provisioning: seed's room_unit b4444444 has capacity 2, so it should have exactly
-- two beds, labeled Bed 1 / Bed 2, created by the same INSERT that created the room_unit.
select results_eq(
  $$ select bed_label from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' order by bed_label $$,
  $$ values ('Bed 1'), ('Bed 2') $$,
  'a capacity-2 room_unit gets exactly two auto-provisioned beds'
);

-- The actual double-booking guard: two holds on the same bed cannot both be active.
select lives_ok(
  $$ insert into public.bookings (
       property_id, room_unit_id, bed_id, phone, billing_cycle,
       security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
       held_expires_at
     )
     select '33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444', id,
       '+919876512345', 'monthly', 500000, 800000, 100000, 1400000, now() + interval '10 minutes'
     from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1' $$,
  'the first hold on a bed succeeds'
);

select throws_ok(
  $$ insert into public.bookings (
       property_id, room_unit_id, bed_id, phone, billing_cycle,
       security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
       held_expires_at
     )
     select '33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444', id,
       '+919876554321', 'monthly', 500000, 800000, 100000, 1400000, now() + interval '10 minutes'
     from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1' $$,
  '23505',
  null,
  'a second concurrent hold on the same bed is rejected — exactly one wins'
);

-- A hold on a *different* bed in the same room_unit is unaffected.
select lives_ok(
  $$ insert into public.bookings (
       property_id, room_unit_id, bed_id, phone, billing_cycle,
       security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
       held_expires_at
     )
     select '33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444', id,
       '+919876500000', 'monthly', 500000, 800000, 100000, 1400000, now() + interval '10 minutes'
     from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 2' $$,
  'a hold on a different bed in the same room succeeds independently'
);

-- Once the first hold is no longer active (expired), the same bed can be held again.
update public.bookings set status = 'expired'
where bed_id = (select id from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1')
  and phone = '+919876512345';

select lives_ok(
  $$ insert into public.bookings (
       property_id, room_unit_id, bed_id, phone, billing_cycle,
       security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
       held_expires_at
     )
     select '33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444', id,
       '+919876511111', 'monthly', 500000, 800000, 100000, 1400000, now() + interval '10 minutes'
     from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1' $$,
  'a bed frees up again once the prior hold on it is no longer active'
);

select * from finish();
rollback;
