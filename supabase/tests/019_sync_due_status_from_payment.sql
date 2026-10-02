begin;
select plan(7);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- Seed due d6666666 (tenant A, "Fake Tenant Approved") starts unpaid.
select is(
  (select status from public.dues where id = 'd6666666-6666-6666-6666-666666666666'),
  'unpaid'::public.due_status,
  'sanity: the seeded due starts unpaid'
);

-- Recording a manual payment against it (the admin screen's own write shape) marks it
-- paid via trigger — not application code setting dues.status directly.
select lives_ok(
  $$ insert into public.payments (due_id, tenant_id, amount_paise, source, status, method, paid_at, recorded_by)
     values ('d6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666', 1000000, 'manual', 'paid', 'cash', now(), 'a1111111-1111-1111-1111-111111111111') $$,
  'admin can record a manual payment against a due'
);
select is(
  (select status from public.dues where id = 'd6666666-6666-6666-6666-666666666666'),
  'paid'::public.due_status,
  'the due is marked paid by the sync trigger, not by a second write'
);

-- A fresh due + a payment inserted as something other than 'paid' (e.g. 'created', the
-- Razorpay-order stage) does not touch the due at all.
insert into public.dues (id, tenant_id, type, amount_paise, due_date, status, created_by)
values ('d6666667-6666-6666-6666-666666666667', '66666666-6666-6666-6666-666666666666', 'rent', 1000000, current_date, 'unpaid', 'a1111111-1111-1111-1111-111111111111');
select lives_ok(
  $$ insert into public.payments (id, due_id, tenant_id, amount_paise, source, status)
     values ('b6666667-6666-6666-6666-666666666667', 'd6666667-6666-6666-6666-666666666667', '66666666-6666-6666-6666-666666666666', 1000000, 'razorpay', 'created') $$,
  'a payment can be created in a non-paid state (e.g. a pending Razorpay order)'
);
select is(
  (select status from public.dues where id = 'd6666667-6666-6666-6666-666666666667'),
  'unpaid'::public.due_status,
  'a payment that is not yet paid does not mark the due paid'
);

-- Updating that same payment to paid (the eventual webhook transition) triggers the sync.
select lives_ok(
  $$ update public.payments set status = 'paid', paid_at = now()
     where id = 'b6666667-6666-6666-6666-666666666667' $$,
  'updating a payment to paid is allowed'
);
select is(
  (select status from public.dues where id = 'd6666667-6666-6666-6666-666666666667'),
  'paid'::public.due_status,
  'the due syncs to paid when the payment transitions to paid via UPDATE, not just INSERT'
);

select * from finish();
rollback;
