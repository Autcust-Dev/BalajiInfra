begin;
select plan(12);

-- Owner: full access to admins, properties, app_config.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

select isnt_empty(
  $$ select * from public.admins $$,
  'owner can read admins'
);
select isnt_empty(
  $$ select * from public.properties $$,
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

-- Staff: denied on admins/properties/app_config writes (owner-only tier).
select set_config('request.jwt.claims', json_build_object(
  'sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

select is_empty(
  $$ select * from public.admins $$,
  'staff cannot read admins (owner-only table)'
);
select is_empty(
  $$ select * from public.properties $$,
  'staff cannot read properties (owner-only table)'
);
select throws_ok(
  $$ insert into public.properties (name, address) values ('Staff PG', 'Nowhere') $$,
  '42501',
  null,
  'staff cannot insert properties'
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
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001'
)::text, true);
select isnt_empty(
  $$ select * from public.app_config $$,
  'authenticated tenant can read app_config'
);

select * from finish();
rollback;
