begin;
select plan(4);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

select throws_ok(
  $$ insert into public.dues (tenant_id, type, amount_paise, due_date, created_by)
     values ('66666666-6666-6666-6666-666666666666', 'other', 0, current_date, 'a1111111-1111-1111-1111-111111111111') $$,
  '23514',
  null,
  'dues.amount_paise must be > 0'
);
select throws_ok(
  $$ insert into public.payments (due_id, tenant_id, amount_paise, source, status)
     values ('d6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666', -100, 'manual', 'created') $$,
  '23514',
  null,
  'payments.amount_paise must be > 0'
);
select throws_ok(
  $$ insert into public.tenants (property_id, room_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
     values ('33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444', 'Bad Phone', '9876500009', 'active', 'not_started', current_date, 500000) $$,
  '23514',
  null,
  'tenants.phone must match +91 followed by 10 digits'
);
select throws_ok(
  $$ update public.kyc_submissions set status = 'rejected', rejection_reason = null
     where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  '23514',
  null,
  'kyc_submissions.rejection_reason is required when status = rejected'
);

select * from finish();
rollback;
