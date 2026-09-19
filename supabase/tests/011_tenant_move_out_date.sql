begin;
select plan(5);

-- Check constraint: move_out_date is required once status = moved_out.
select throws_ok(
  $$ update public.tenants set status = 'moved_out', move_out_date = null
     where id = '66666666-6666-6666-6666-666666666666' $$,
  '23514',
  null,
  'moving a tenant out without a move_out_date violates the check constraint'
);

set local role authenticated;

-- Tenant cannot set their own move_out_date (still restricted to fcm_token only — the
-- guard's compared column list now includes move_out_date too).
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select throws_ok(
  $$ update public.tenants set move_out_date = current_date
     where id = '66666666-6666-6666-6666-666666666666' $$,
  'P0001',
  'tenants: only fcm_token may be updated by a tenant',
  'tenant cannot set their own move_out_date'
);

-- Admin (owner) can move a tenant out with a move_out_date.
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select lives_ok(
  $$ update public.tenants set status = 'moved_out', move_out_date = current_date
     where id = '66666666-6666-6666-6666-666666666666' $$,
  'admin can move a tenant out with a move_out_date'
);
select is(
  (select status from public.tenants where id = '66666666-6666-6666-6666-666666666666'),
  'moved_out'::public.tenant_status,
  'status actually moved to moved_out'
);

-- The seed fixture for the already-moved-out tenant (tenant C) satisfies the constraint.
select ok(
  (select move_out_date from public.tenants where id = '88888888-8888-8888-8888-888888888888') is not null,
  'the moved-out seed fixture has a move_out_date set'
);

select * from finish();
rollback;
