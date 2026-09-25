begin;
select plan(11);

-- pricing_plans, beds, bookings, whatsapp_invoice_log: admin-only via RLS (grants exist for
-- `authenticated` so a signed-in tenant doesn't hit a bare permission error, but is_admin()
-- filters them to zero rows — same "RLS-filtered, not an error" pattern already proven for
-- rooms/floors/blocks). `anon` gets no grant at all, so it hits a hard permission error.
-- The public self-signup flow never reads these tables directly either way — only through
-- service_role Edge Functions (a later PR).

set local role anon;
select throws_ok(
  $$ select * from public.pricing_plans $$, '42501', null, 'anon cannot read pricing_plans'
);
select throws_ok(
  $$ select * from public.beds $$, '42501', null, 'anon cannot read beds'
);
select throws_ok(
  $$ select * from public.bookings $$, '42501', null, 'anon cannot read bookings'
);
select throws_ok(
  $$ select * from public.whatsapp_invoice_log $$, '42501', null, 'anon cannot read whatsapp_invoice_log'
);

-- An approved, active tenant (a real signed-in app user, but not an admin) has a table
-- grant via `authenticated` but no matching RLS policy, so every read is silently filtered
-- to zero rows rather than erroring.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select is_empty(
  $$ select * from public.pricing_plans $$, 'a signed-in tenant reads zero pricing_plans rows (RLS-filtered, not an error)'
);
select is_empty(
  $$ select * from public.beds $$, 'a signed-in tenant reads zero beds rows (RLS-filtered, not an error)'
);
select is_empty(
  $$ select * from public.bookings $$, 'a signed-in tenant reads zero bookings rows (RLS-filtered, not an error)'
);

-- An owner admin has full access to all four, same as every other admin-managed table.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select lives_ok(
  $$ insert into public.pricing_plans (
       property_id, capacity, security_deposit_paise, rent_monthly_paise, rent_yearly_paise, onboarding_charges_paise
     ) values ('33333333-3333-3333-3333-333333333333', 1, 500000, 800000, 9000000, 100000) $$,
  'owner admin can create a pricing plan'
);
select isnt_empty(
  $$ select * from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' $$,
  'owner admin can read beds'
);
select lives_ok(
  $$ insert into public.bookings (
       property_id, room_unit_id, bed_id, phone, billing_cycle,
       security_deposit_paise, rent_paise, onboarding_charges_paise, total_amount_paise,
       held_expires_at
     )
     select '33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444', id,
       '+919876599999', 'monthly', 500000, 800000, 100000, 1400000, now() + interval '10 minutes'
     from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1' $$,
  'owner admin can create a booking'
);
select isnt_empty(
  $$ select * from public.bookings $$,
  'owner admin can read the booking just created'
);

select * from finish();
rollback;
