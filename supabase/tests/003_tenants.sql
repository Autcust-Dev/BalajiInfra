begin;
select plan(10);

set local role authenticated;

-- Tenant A (approved, active) reads only their own row, not tenant B's or the moved-out
-- tenant's.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select results_eq(
  $$ select id from public.tenants order by id $$,
  $$ values ('66666666-6666-6666-6666-666666666666'::uuid) $$,
  'tenant A sees only their own tenant row, not tenant B or the moved-out tenant'
);

-- Tenant with status = moved_out: no access at all, even to their own row.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-movedout', 'role', 'authenticated', 'phone_number', '+919876500003',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select is_empty(
  $$ select * from public.tenants $$,
  'moved-out tenant has no access to tenants at all'
);

-- Tenant A may update fcm_token on their own row.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select lives_ok(
  $$ update public.tenants set fcm_token = 'fake-fcm-token' where id = '66666666-6666-6666-6666-666666666666' $$,
  'tenant can update their own fcm_token'
);
select is(
  (select fcm_token from public.tenants where id = '66666666-6666-6666-6666-666666666666'),
  'fake-fcm-token',
  'fcm_token update actually took effect'
);

-- Tenant A may NOT touch any other column on their own row (rent, phone, status, ...).
select throws_ok(
  $$ update public.tenants set monthly_rent_paise = 1 where id = '66666666-6666-6666-6666-666666666666' $$,
  'P0001',
  'tenants: only fcm_token may be updated by a tenant',
  'tenant cannot change their own rent'
);
select throws_ok(
  $$ update public.tenants set status = 'moved_out' where id = '66666666-6666-6666-6666-666666666666' $$,
  'P0001',
  'tenants: only fcm_token may be updated by a tenant',
  'tenant cannot self-approve a status change'
);
-- RLS makes tenant B's row invisible to tenant A, so the UPDATE matches zero rows rather
-- than erroring. Confirm it's a no-op by checking as owner afterwards.
select lives_ok(
  $$ update public.tenants set kyc_status = 'approved' where id = '77777777-7777-7777-7777-777777777777' $$,
  'update against another tenant''s row runs without error (RLS just filters it to 0 rows)'
);

-- Tenant cannot insert or delete tenants at all (no self-registration — CLAUDE.md rule 1).
select throws_ok(
  $$ insert into public.tenants (property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
     values ('33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444', 'Self Registered', '+919876500009', 'active', 'not_started', now(), 100000) $$,
  '42501',
  null,
  'tenant cannot self-register'
);

-- Admin (owner) has full access, including editing rent.
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select lives_ok(
  $$ update public.tenants set monthly_rent_paise = 1200000 where id = '66666666-6666-6666-6666-666666666666' $$,
  'admin can update a tenant''s rent'
);
select is(
  (select kyc_status from public.tenants where id = '77777777-7777-7777-7777-777777777777'),
  'submitted'::public.kyc_status,
  'tenant A''s earlier update against tenant B''s row was actually a no-op'
);

select * from finish();
rollback;
