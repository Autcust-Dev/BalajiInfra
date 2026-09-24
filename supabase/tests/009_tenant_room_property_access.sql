begin;
select plan(9);

set local role authenticated;

-- Approved, active tenant A reads their own room and property, and nothing else — not
-- tenant B's room, and not the unrelated "Other Fake PG Chennai" property/room.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);

select results_eq(
  $$ select id from public.rooms $$,
  $$ values ('44444444-4444-4444-4444-444444444444'::uuid) $$,
  'approved tenant sees only their own room'
);
select results_eq(
  $$ select id from public.properties $$,
  $$ values ('33333333-3333-3333-3333-333333333333'::uuid) $$,
  'approved tenant sees only their own property'
);
select is_empty(
  $$ select * from public.rooms where id = '55555555-5555-5555-5555-555555555555' $$,
  'approved tenant cannot read tenant B''s room'
);
select is_empty(
  $$ select * from public.rooms where id = 'e0000000-0000-0000-0000-000000000000' $$,
  'approved tenant cannot read an unrelated property''s room'
);
select is_empty(
  $$ select * from public.properties where id = '99999999-9999-9999-9999-999999999999' $$,
  'approved tenant cannot read an unrelated property'
);

-- Non-approved tenant B: zero access to rooms/properties (main-app tier requires
-- kyc_status = approved, same gate as dues/payments).
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-pending', 'role', 'authenticated', 'phone_number', '+919876500002',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select is_empty(
  $$ select * from public.rooms $$,
  'non-approved tenant has no access to rooms at all'
);
select is_empty(
  $$ select * from public.properties $$,
  'non-approved tenant has no access to properties at all'
);

-- Tenants cannot write rooms/properties either way — there's no UPDATE/ALL policy for
-- tenants on either table (only SELECT), so the row simply isn't visible to the UPDATE
-- command at all: it matches zero rows rather than erroring (same RLS-filtered pattern as
-- the admins/properties staff tests).
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select lives_ok(
  $$ update public.rooms set room_number = '999' where id = '44444444-4444-4444-4444-444444444444' $$,
  'approved tenant''s update against their own room runs without error (RLS filters it to 0 rows)'
);
select isnt(
  (select room_number from public.rooms where id = '44444444-4444-4444-4444-444444444444'),
  '999',
  'the tenant''s update against their own room was actually a no-op'
);

select * from finish();
rollback;
