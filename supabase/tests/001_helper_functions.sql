begin;
select plan(12);

-- Owner admin, aal2 satisfied.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select ok(public.is_admin(), 'owner with aal2 is_admin() = true');
select ok(public.is_owner(), 'owner with aal2 is_owner() = true');
select ok(not public.is_tenant(), 'owner is not a tenant');

-- Staff admin, aal2 satisfied: admin but not owner.
select set_config('request.jwt.claims', json_build_object(
  'sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select ok(public.is_admin(), 'staff with aal2 is_admin() = true');
select ok(not public.is_owner(), 'staff is not owner');

-- Owner admin WITHOUT aal2 (MFA not satisfied): must not count as admin.
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal1'
)::text, true);
select ok(not public.is_admin(), 'owner without aal2 is_admin() = false');

-- Firebase tenant session: non-uuid sub must not blow up is_admin()/is_owner(), and
-- is_tenant()/current_tenant_id() must resolve correctly given a matching aud/iss
-- (seed.sql sets the local firebase_project_id to 'balajiinfra-local-dev').
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select lives_ok(
  $$ select public.is_admin() $$,
  'is_admin() does not raise for a non-uuid (Firebase) sub'
);
select ok(not public.is_admin(), 'Firebase tenant session is_admin() = false');
select ok(public.is_tenant(), 'matched tenant with correct aud/iss is_tenant() = true');
select is(
  public.current_tenant_id(), '66666666-6666-6666-6666-666666666666'::uuid,
  'current_tenant_id() resolves the matched tenant'
);

-- Same sub/phone, but wrong aud (wrong Firebase project) — must NOT be treated as a
-- tenant. Proves the iss/aud check actually does something, not just a well-formed no-op.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'some-other-firebase-project', 'iss', 'https://securetoken.google.com/some-other-firebase-project'
)::text, true);
select ok(not public.is_tenant(), 'wrong aud/iss (different Firebase project) is_tenant() = false');

-- Same sub/phone, aud/iss missing entirely — must also fail closed.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001'
)::text, true);
select ok(not public.is_tenant(), 'missing aud/iss is_tenant() = false (fails closed)');

select * from finish();
rollback;
