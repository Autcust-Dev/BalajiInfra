begin;
select plan(5);

-- Constraint: cannot be negative.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select throws_ok(
  $$ update public.tenants set advance_paise = -1 where id = '66666666-6666-6666-6666-666666666666' $$,
  '23514',
  null,
  'advance_paise cannot be negative'
);

-- Zero is a valid advance (no advance collected).
select lives_ok(
  $$ update public.tenants set advance_paise = 0 where id = '66666666-6666-6666-6666-666666666666' $$,
  'zero is a valid advance_paise'
);

-- Admin can set a real advance amount, and it doesn't disturb other columns (the "editing
-- one field shouldn't affect others" requirement).
select lives_ok(
  $$ update public.tenants set advance_paise = 500000 where id = '66666666-6666-6666-6666-666666666666' $$,
  'admin can set a real advance amount'
);
select is(
  (select monthly_rent_paise from public.tenants where id = '66666666-6666-6666-6666-666666666666'),
  1000000::bigint,
  'setting advance_paise does not touch monthly_rent_paise'
);

-- A tenant cannot set their own advance_paise (protected by the self-update guard, same
-- as every other admin-only tenant column).
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select throws_ok(
  $$ update public.tenants set advance_paise = 999 where id = '66666666-6666-6666-6666-666666666666' $$,
  'P0001',
  'tenants: only fcm_token may be updated by a tenant',
  'tenant cannot set their own advance_paise'
);

select * from finish();
rollback;
