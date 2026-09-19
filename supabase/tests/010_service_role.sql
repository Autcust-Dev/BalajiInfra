begin;
select plan(9);

-- service_role's BYPASSRLS attribute skips row-level policies, but NOT the base table
-- privilege system — every table needed a real GRANT added for it in this changeset (it
-- had none before, which would have silently broken every Edge Function). Confirm the
-- writes each Edge Function actually needs now work, and that the tenant-vs-admin trigger
-- guards on tenants/kyc_submissions don't block service_role either (they only restrict
-- the literal `authenticated` role).

set local role service_role;

-- razorpay-webhook: idempotency ledger, inserting/updating a payment, marking a due paid.
select lives_ok(
  $$ insert into public.webhook_events (provider, event_id, payload)
     values ('razorpay', 'evt_test_1', '{"foo":"bar"}') $$,
  'service_role can insert into webhook_events'
);
select lives_ok(
  $$ update public.webhook_events set processed_at = now() where event_id = 'evt_test_1' $$,
  'service_role can update webhook_events'
);
select lives_ok(
  $$ insert into public.payments (id, due_id, tenant_id, amount_paise, source, status, razorpay_order_id, razorpay_payment_id)
     values ('f1111111-1111-1111-1111-111111111111', 'd6666666-6666-6666-6666-666666666666',
             '66666666-6666-6666-6666-666666666666', 1000000, 'razorpay', 'created', 'order_test_1', null) $$,
  'service_role can insert a razorpay payment (create-order path)'
);
select lives_ok(
  $$ update public.payments set status = 'paid', razorpay_payment_id = 'pay_test_1', paid_at = now()
     where id = 'f1111111-1111-1111-1111-111111111111' $$,
  'service_role can update a payment to paid (webhook path)'
);
select lives_ok(
  $$ update public.dues set status = 'paid' where id = 'd6666666-6666-6666-6666-666666666666' $$,
  'service_role can mark a due as paid'
);

-- firebase_uid linking on first login (Phase 3): service_role updates tenants, bypassing
-- the tenant_update_guard trigger (it only restricts the literal `authenticated` role, not
-- service_role).
select lives_ok(
  $$ update public.tenants set firebase_uid = 'firebase-newly-linked'
     where id = '66666666-6666-6666-6666-666666666666' $$,
  'service_role can update tenants.firebase_uid, unrestricted by the tenant column guard'
);

-- audit_log records these as a system actor, not admin/tenant (no JWT claims are set for
-- service_role here, matching a real Edge Function call, which never sets
-- request.jwt.claims on its own service-role connection).
reset role;
select ok(
  exists (
    select 1 from public.audit_log
    where table_name = 'payments' and action = 'INSERT' and actor_type = 'service_role'
      and row_id = 'f1111111-1111-1111-1111-111111111111'
  ),
  'the service_role payment insert was logged with actor_type = service_role'
);
select ok(
  exists (
    select 1 from public.audit_log
    where table_name = 'tenants' and action = 'UPDATE' and actor_type = 'service_role'
      and row_id = '66666666-6666-6666-6666-666666666666'
  ),
  'the service_role tenants update was logged with actor_type = service_role'
);
select is_empty(
  $$ select * from public.audit_log where table_name = 'webhook_events' $$,
  'webhook_events writes are not audited at all (no audit_log_row trigger attached there)'
);

select * from finish();
rollback;
