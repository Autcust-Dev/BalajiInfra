begin;
select plan(12);

-- anon: no grant at all on any of the three (rooms already tested elsewhere; these three
-- are new in this branch).
set local role anon;
select throws_ok(
  $$ select * from public.floors $$, '42501', null, 'anon cannot read floors'
);
select throws_ok(
  $$ select * from public.blocks $$, '42501', null, 'anon cannot read blocks'
);
select throws_ok(
  $$ select * from public.room_units $$, '42501', null, 'anon cannot read room_units'
);

-- A non-approved tenant (kyc submitted, not approved) has zero access — same "main-app
-- tier requires approved KYC" gate as rooms/properties.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-pending', 'role', 'authenticated', 'phone_number', '+919876500002',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select is_empty(
  $$ select * from public.floors $$, 'a non-approved tenant has no access to floors'
);
select is_empty(
  $$ select * from public.blocks $$, 'a non-approved tenant has no access to blocks'
);
select is_empty(
  $$ select * from public.room_units $$, 'a non-approved tenant has no access to room_units'
);

-- An approved, active tenant reads only their own floor/block/room_unit — room b4444444
-- (property 33333333) is unassigned to any block in seed data, so an approved tenant in
-- that room sees zero floors/blocks (no block assigned) but does see their own room_unit.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select isnt_empty(
  $$ select * from public.room_units where id = 'b4444444-4444-4444-4444-444444444444' $$,
  'an approved tenant can read their own room_unit'
);
select is_empty(
  $$ select * from public.room_units where id = 'b5555555-5555-5555-5555-555555555555' $$,
  'an approved tenant cannot read a different room_unit'
);

-- Assign a floor+block to that room and re-check: the tenant now sees exactly their own
-- floor/block, nothing else.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
insert into public.floors (id, property_id, name) values
  ('11111112-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'Ground Floor'),
  ('11111113-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'First Floor');
insert into public.blocks (id, floor_id, name) values
  ('22222223-2222-2222-2222-222222222222', '11111112-1111-1111-1111-111111111111', 'Block A');
update public.rooms set block_id = '22222223-2222-2222-2222-222222222222'
where id = '44444444-4444-4444-4444-444444444444';

select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select results_eq(
  $$ select id from public.floors $$,
  $$ values ('11111112-1111-1111-1111-111111111111'::uuid) $$,
  'an approved tenant sees only their own floor (Ground Floor), not the unrelated First Floor'
);
select results_eq(
  $$ select id from public.blocks $$,
  $$ values ('22222223-2222-2222-2222-222222222222'::uuid) $$,
  'an approved tenant sees only their own block'
);

-- Admin has full access to all three.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select is(
  (select count(*) from public.floors)::integer, 2, 'admin sees all floors'
);
select is(
  (select count(*) from public.room_units)::integer, 3, 'admin sees all room_units'
);

select * from finish();
rollback;
