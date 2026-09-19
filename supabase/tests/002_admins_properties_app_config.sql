begin;
select plan(16);

-- Owner: full access to admins, properties, app_config.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

select results_eq(
  $$ select count(*) from public.admins $$,
  $$ values (2::bigint) $$,
  'owner reads both admin rows'
);
select ok(
  (select count(*) from public.properties) >= 1,
  'owner can read properties'
);
select lives_ok(
  $$ insert into public.app_config (key, value) values ('min_app_version', '{"android":"1.0.0","ios":"1.0.0"}') $$,
  'owner can write app_config'
);
select lives_ok(
  $$ update public.properties set name = 'Renamed by owner' where id = '33333333-3333-3333-3333-333333333333' $$,
  'owner can update properties'
);

-- Staff: read-only on admins (own row only) and properties (all rows); still denied on
-- every write to either, and on app_config entirely (CLAUDE.md Phase 1 addition, refined).
select set_config('request.jwt.claims', json_build_object(
  'sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

select results_eq(
  $$ select id from public.admins $$,
  $$ values ('a2222222-2222-2222-2222-222222222222'::uuid) $$,
  'staff reads only their own admins row, not the owner''s'
);
-- Staff has only a SELECT policy on admins, so this UPDATE isn't authorization-erred —
-- RLS just makes the row invisible to the UPDATE command, matching zero rows silently
-- (same behavior as any other RLS-filtered UPDATE; see the tenants tests for the same
-- pattern). Confirm it's a genuine no-op by re-checking as owner afterwards.
select lives_ok(
  $$ update public.admins set active = false where id = 'a2222222-2222-2222-2222-222222222222' $$,
  'staff''s update against their own admins row runs without error (RLS filters it to 0 rows)'
);
select ok(
  (select count(*) from public.properties) >= 2,
  'staff can read all properties, not just one'
);
select throws_ok(
  $$ insert into public.properties (name, address) values ('Staff PG', 'Nowhere') $$,
  '42501',
  null,
  'staff cannot insert properties'
);
-- Same pattern as the admins update above: RLS-filtered, not an authorization error.
select lives_ok(
  $$ update public.properties set name = 'Hacked by staff' where id = '33333333-3333-3333-3333-333333333333' $$,
  'staff''s update against properties runs without error (RLS filters it to 0 rows)'
);
select throws_ok(
  $$ insert into public.app_config (key, value) values ('current_policy_version', '"v1"') $$,
  '42501',
  null,
  'staff cannot write app_config'
);
select throws_ok(
  $$ insert into public.admins (user_id, name, role) values (gen_random_uuid(), 'Rogue Admin', 'owner') $$,
  '42501',
  null,
  'staff cannot insert into admins'
);

-- Confirm both of staff's "no-op" updates above genuinely changed nothing.
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select ok(
  (select active from public.admins where id = 'a2222222-2222-2222-2222-222222222222') = true,
  'staff''s update against their own admins row was actually a no-op'
);
select is(
  (select name from public.properties where id = '33333333-3333-3333-3333-333333333333'),
  'Renamed by owner',
  'staff''s update against properties was actually a no-op'
);

-- app_config is readable by anon and authenticated (public, pre-login min_app_version check).
select set_config('request.jwt.claims', '{}', true);
set local role anon;
select isnt_empty(
  $$ select * from public.app_config $$,
  'anon can read app_config'
);
select throws_ok(
  $$ insert into public.app_config (key, value) values ('x', '"y"') $$,
  '42501',
  null,
  'anon cannot write app_config'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select isnt_empty(
  $$ select * from public.app_config $$,
  'authenticated tenant can read app_config'
);

select * from finish();
rollback;
