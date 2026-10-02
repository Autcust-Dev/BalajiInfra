begin;
select plan(9);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- An active tenant can never be deleted, even by an admin, regardless of dues.
select throws_ok(
  $$ delete from public.tenants where id = '66666666-6666-6666-6666-666666666666' $$,
  'P0001',
  'tenants: only a moved-out tenant can be deleted',
  'an active tenant cannot be deleted'
);

-- A moved-out tenant with an unpaid due still cannot be deleted.
update public.tenants set status = 'moved_out', move_out_date = current_date
  where id = '66666666-6666-6666-6666-666666666666';
select is(
  (select status from public.dues where id = 'd6666666-6666-6666-6666-666666666666'),
  'unpaid'::public.due_status,
  'sanity: the seeded due is still unpaid'
);
select throws_ok(
  $$ delete from public.tenants where id = '66666666-6666-6666-6666-666666666666' $$,
  'P0001',
  'tenants: cannot delete a tenant with unpaid dues — settle or cancel every due first',
  'a moved-out tenant with an unpaid due cannot be deleted'
);

-- Once every due is settled (paid or cancelled), deletion is allowed — and cascades through
-- their now-fully-settled dues/payments/fines.
update public.dues set status = 'paid' where id = 'd6666666-6666-6666-6666-666666666666';
insert into public.payments (due_id, tenant_id, amount_paise, source, status, paid_at, recorded_by)
values ('d6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666', 1000000, 'manual', 'paid', now(), 'a1111111-1111-1111-1111-111111111111');
insert into public.fines (due_id, amount_paise, starts_on, ends_on, created_by)
values ('d6666666-6666-6666-6666-666666666666', 5000, current_date, current_date + 1, 'a1111111-1111-1111-1111-111111111111');

select lives_ok(
  $$ delete from public.tenants where id = '66666666-6666-6666-6666-666666666666' $$,
  'a moved-out tenant with every due settled can be deleted'
);
select is_empty(
  $$ select * from public.dues where tenant_id = '66666666-6666-6666-6666-666666666666' $$,
  'their dues are cascade-deleted along with them'
);
select is_empty(
  $$ select * from public.payments where tenant_id = '66666666-6666-6666-6666-666666666666' $$,
  'their payments are cascade-deleted along with them'
);
select is_empty(
  $$ select * from public.fines where due_id = 'd6666666-6666-6666-6666-666666666666' $$,
  'fines on their due are cascade-deleted along with it'
);

-- The actual point of this: the freed phone number can now be reused by a brand-new tenant
-- (the "they may need to join back" case).
select lives_ok(
  $$ insert into public.tenants (property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
     values ('33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444', 'Rejoined Tenant', '+919876500001', 'active', 'not_started', current_date, 1000000) $$,
  'the freed phone number can be reused by a new tenant after the old one is deleted'
);

-- A cancelled (not paid) due also counts as settled — doesn't block deletion either.
insert into public.dues (id, tenant_id, type, amount_paise, due_date, status, created_by)
values ('d7777777-7777-7777-7777-777777777779', '77777777-7777-7777-7777-777777777777', 'other', 100, current_date, 'cancelled', 'a1111111-1111-1111-1111-111111111111');
update public.tenants set status = 'moved_out', move_out_date = current_date
  where id = '77777777-7777-7777-7777-777777777777';
select lives_ok(
  $$ delete from public.tenants where id = '77777777-7777-7777-7777-777777777777' $$,
  'a moved-out tenant whose only due is cancelled (not paid) can still be deleted'
);

select * from finish();
rollback;
