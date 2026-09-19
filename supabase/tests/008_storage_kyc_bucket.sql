begin;
select plan(5);

set local role authenticated;

-- Tenant A has no kyc_submissions row yet (seed only gives tenant B one), so nothing blocks
-- a first upload into their own folder.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('kyc', '66666666-6666-6666-6666-666666666666/sub1/aadhaar.jpg') $$,
  'tenant can upload into their own folder'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('kyc', '77777777-7777-7777-7777-777777777777/sub1/aadhaar.jpg') $$,
  '42501',
  null,
  'tenant cannot upload into another tenant''s folder'
);
select isnt_empty(
  $$ select * from storage.objects where bucket_id = 'kyc' and name = '66666666-6666-6666-6666-666666666666/sub1/aadhaar.jpg' $$,
  'tenant can read back their own uploaded object'
);

-- Tenant B already has a kyc_submissions row with status = submitted (from seed), which
-- blocks further uploads until it's not_started/rejected (CLAUDE.md §4 rule 20).
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-pending', 'role', 'authenticated', 'phone_number', '+919876500002',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('kyc', '77777777-7777-7777-7777-777777777777/sub2/aadhaar.jpg') $$,
  '42501',
  null,
  'tenant cannot upload while their submission is already submitted (not not_started/rejected)'
);
select is_empty(
  $$ select * from storage.objects where bucket_id = 'kyc' and name = '66666666-6666-6666-6666-666666666666/sub1/aadhaar.jpg' $$,
  'tenant B cannot read tenant A''s uploaded object'
);

select * from finish();
rollback;
