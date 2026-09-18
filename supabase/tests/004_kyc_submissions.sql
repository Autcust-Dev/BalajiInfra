begin;
select plan(11);

set local role authenticated;

-- Tenant B (kyc_status = submitted, not yet approved) can read their own tenant row,
-- consents, and kyc_submissions even though not approved (CLAUDE.md Phase 1 addition).
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-pending', 'role', 'authenticated', 'phone_number', '+919876500002'
)::text, true);
select isnt_empty(
  $$ select * from public.tenants where id = '77777777-7777-7777-7777-777777777777' $$,
  'non-approved tenant can read their own tenant row'
);
select isnt_empty(
  $$ select * from public.kyc_submissions where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'non-approved tenant can read their own kyc_submissions row'
);

-- ...but NOT dues or payments (main-app tier requires kyc_status = approved).
select is_empty(
  $$ select * from public.dues $$,
  'non-approved tenant has no access to dues'
);

-- A tenant can never set status to approved/rejected themselves, even while resubmitting
-- from 'rejected' or while already 'submitted'.
select throws_ok(
  $$ update public.kyc_submissions set status = 'approved' where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'P0001',
  'kyc_submissions: can only be updated while not_started or rejected',
  'tenant cannot approve their own KYC while status = submitted'
);

-- Setup: admin rejects tenant B's submission, then switch back to tenant B to prove they
-- can't tamper with the review fields on resubmit.
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
update public.kyc_submissions set status = 'rejected', reviewed_by = 'a1111111-1111-1111-1111-111111111111',
  reviewed_at = now(), rejection_reason = 'blurry photo'
where tenant_id = '77777777-7777-7777-7777-777777777777';

select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-pending', 'role', 'authenticated', 'phone_number', '+919876500002'
)::text, true);
select throws_ok(
  $$ update public.kyc_submissions set status = 'submitted', rejection_reason = null
     where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'P0001',
  'kyc_submissions: only aadhaar/selfie fields and status may be updated by a tenant',
  'tenant cannot clear rejection_reason on resubmit'
);

-- Tenant CAN resubmit (move rejected -> submitted) without touching review fields.
select lives_ok(
  $$ update public.kyc_submissions set status = 'submitted', aadhaar_path = 'new/path/aadhaar.jpg'
     where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'tenant can resubmit after rejection without touching review fields'
);
select is(
  (select status from public.kyc_submissions where tenant_id = '77777777-7777-7777-7777-777777777777'),
  'submitted'::public.kyc_status,
  'resubmission actually moved status to submitted'
);
select is(
  (select kyc_status from public.tenants where id = '77777777-7777-7777-7777-777777777777'),
  'submitted'::public.kyc_status,
  'tenants.kyc_status mirrors the resubmission via the sync trigger'
);

-- Admin (owner) approves/rejects: reviewed_by/reviewed_at/rejection_reason all admin-only.
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select lives_ok(
  $$ update public.kyc_submissions
     set status = 'approved', reviewed_by = 'a1111111-1111-1111-1111-111111111111', reviewed_at = now()
     where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'admin can approve a KYC submission'
);
select is(
  (select kyc_status from public.tenants where id = '77777777-7777-7777-7777-777777777777'),
  'approved'::public.kyc_status,
  'tenants.kyc_status mirrors the admin approval via the sync trigger'
);

-- rejection_reason is required when status = rejected (CLAUDE.md Phase 1 addition,
-- check constraint).
select throws_ok(
  $$ update public.kyc_submissions set status = 'rejected', rejection_reason = null
     where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  '23514',
  null,
  'rejecting without a rejection_reason violates the check constraint'
);

select * from finish();
rollback;
