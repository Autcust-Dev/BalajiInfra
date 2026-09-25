begin;
select plan(6);

-- kyc_submissions delete support (new in this branch): admin-only, and the tenants.kyc_status
-- sync trigger fires on DELETE too, resetting the tenant back to not_started so they can
-- resubmit. This underpins the kyc-delete Edge Function (require_admin-gated) but is
-- tested here at the RLS/trigger layer, which pgTAP can actually reach — the Edge
-- Function's own HTTP-level behavior (admin-only signed URLs, audit logging of every
-- view/download) is verified separately, manually, since pgTAP cannot invoke Edge
-- Functions.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-pending', 'role', 'authenticated', 'phone_number', '+919876500002',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
-- DELETE is granted at the table level (authenticated) so admins can use it; only the
-- admin-only RLS policy actually gates it, so a tenant's own delete attempt runs without
-- error but matches zero rows (same "RLS-filtered, not an error" pattern as everywhere
-- else in this codebase), rather than throwing a permission error.
select lives_ok(
  $$ delete from public.kyc_submissions where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'a tenant''s delete attempt against their own kyc_submissions row runs without error (RLS filters it to 0 rows)'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
select is(
  (select kyc_status from public.tenants where id = '77777777-7777-7777-7777-777777777777'),
  'submitted'::public.kyc_status,
  'sanity: tenant B''s kyc_status is submitted before the delete'
);
select lives_ok(
  $$ delete from public.kyc_submissions where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'an admin can delete a kyc_submissions row'
);
select is(
  (select kyc_status from public.tenants where id = '77777777-7777-7777-7777-777777777777'),
  'not_started'::public.kyc_status,
  'deleting the submission resets tenants.kyc_status back to not_started via the sync trigger'
);
select is_empty(
  $$ select * from public.kyc_submissions where tenant_id = '77777777-7777-7777-7777-777777777777' $$,
  'the submission is actually gone, allowing a fresh resubmission'
);

-- audit_log service_role INSERT grant (new in this branch — it previously had SELECT
-- only, which the KYC Edge Functions need for their non-DML audit writes).
select ok(
  has_table_privilege('service_role', 'public.audit_log', 'INSERT'),
  'service_role has an explicit INSERT grant on audit_log'
);

select * from finish();
rollback;
