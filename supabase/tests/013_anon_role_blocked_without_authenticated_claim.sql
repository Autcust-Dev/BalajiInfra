begin;
select plan(6);

-- Simulates a Firebase ID token that's missing the `role: "authenticated"` custom claim
-- (CLAUDE.md §4 rule 14 — set by the firebase/functions beforeSignIn blocking function).
-- Supabase's third-party Firebase auth integration reads that claim to pick the Postgres
-- role for the request; without it the session stays `anon`. This proves that failure mode
-- is caught by the table-level GRANTs alone (rule 9), independent of RLS: every
-- tenant-facing table is GRANTed only to `authenticated`, so `anon` gets a permission-denied
-- error rather than an RLS-filtered empty result — a stronger, defense-in-depth guarantee
-- than "RLS happens to return zero rows".
set local role anon;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);

select throws_ok(
  $$ select * from public.tenants $$,
  '42501',
  null,
  'anon (no role claim) cannot select tenants at all — blocked by GRANT, not just RLS'
);
select throws_ok(
  $$ select * from public.consents $$,
  '42501',
  null,
  'anon (no role claim) cannot select consents'
);
select throws_ok(
  $$ select * from public.kyc_submissions $$,
  '42501',
  null,
  'anon (no role claim) cannot select kyc_submissions'
);
select throws_ok(
  $$ select * from public.dues $$,
  '42501',
  null,
  'anon (no role claim) cannot select dues'
);
select throws_ok(
  $$ select * from public.payments $$,
  '42501',
  null,
  'anon (no role claim) cannot select payments'
);
select throws_ok(
  $$ update public.tenants set fcm_token = 'x' where id = '66666666-6666-6666-6666-666666666666' $$,
  '42501',
  null,
  'anon (no role claim) cannot update tenants either'
);

select * from finish();
rollback;
