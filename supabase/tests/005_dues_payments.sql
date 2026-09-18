begin;
select plan(7);

set local role authenticated;

-- Tenant A (approved, active) can read their own due, not anyone else's.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001'
)::text, true);
select results_eq(
  $$ select id from public.dues $$,
  $$ values ('d6666666-6666-6666-6666-666666666666'::uuid) $$,
  'approved tenant reads only their own due'
);

-- Tenant cannot insert or update dues/payments directly — amount is always computed
-- server-side (CLAUDE.md §4 rule 23-24); the client only ever sends a due id.
select throws_ok(
  $$ insert into public.dues (tenant_id, type, amount_paise, due_date, created_by)
     values ('66666666-6666-6666-6666-666666666666', 'other', 500000, current_date, 'a1111111-1111-1111-1111-111111111111') $$,
  '42501',
  null,
  'tenant cannot insert a due'
);
select throws_ok(
  $$ insert into public.payments (due_id, tenant_id, amount_paise, source, status)
     values ('d6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666', 500000, 'razorpay', 'created') $$,
  '42501',
  null,
  'tenant cannot insert a payment directly'
);

-- Tenant B (not yet approved) has zero access to dues/payments.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-pending', 'role', 'authenticated', 'phone_number', '+919876500002'
)::text, true);
select is_empty(
  $$ select * from public.dues $$,
  'non-approved tenant has no access to dues'
);
select is_empty(
  $$ select * from public.payments $$,
  'non-approved tenant has no access to payments'
);

-- Owner and staff (both admin tiers) can record a manual payment (CLAUDE.md §4 rule 27).
select set_config('request.jwt.claims', json_build_object(
  'sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select lives_ok(
  $$ insert into public.payments (due_id, tenant_id, amount_paise, source, status, method, paid_at, recorded_by)
     values ('d6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666', 1000000, 'manual', 'paid', 'cash', now(), 'a2222222-2222-2222-2222-222222222222') $$,
  'staff can record a manual payment'
);
select lives_ok(
  $$ update public.dues set status = 'paid' where id = 'd6666666-6666-6666-6666-666666666666' $$,
  'staff can mark a due as paid'
);

select * from finish();
rollback;
