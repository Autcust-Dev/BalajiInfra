-- Local dev / test seed data only. Fake data — never real tenant/PII data.
-- Fixed UUIDs throughout so pgTAP tests (supabase/tests/) can reference fixtures
-- deterministically without querying back generated ids.

-- Two Supabase Auth users for the two admins below. Minimal columns needed for GoTrue to
-- consider these valid local users; password/MFA enrollment isn't seedable this way, so
-- pgTAP tests simulate aal2 via mocked JWT claims rather than a real TOTP flow.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'owner@example.test', crypt('local-dev-only', gen_salt('bf')),
   now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}'),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'staff@example.test', crypt('local-dev-only', gen_salt('bf')),
   now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}');

insert into public.admins (id, user_id, name, role, active) values
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Fake Owner', 'owner', true),
  ('a2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'Fake Staff', 'staff', true);

insert into public.properties (id, name, address) values
  ('33333333-3333-3333-3333-333333333333', 'Fake PG Bangalore', '123 Fake Street, Bengaluru');

insert into public.rooms (id, property_id, room_number, capacity) values
  ('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', '101', 2),
  ('55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333', '102', 2);

-- Tenant A: active, KYC approved — should have full main-app access (dues/payments).
insert into public.tenants (
  id, property_id, room_id, full_name, phone, firebase_uid, status, kyc_status,
  move_in_date, monthly_rent_paise
) values (
  '66666666-6666-6666-6666-666666666666', '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444', 'Fake Tenant Approved', '+919876500001',
  'firebase-tenant-approved', 'active', 'approved', '2026-01-01', 1000000
);

-- Tenant B: active, KYC submitted but not yet approved — own row/consents/kyc only, no
-- dues/payments.
insert into public.tenants (
  id, property_id, room_id, full_name, phone, firebase_uid, status, kyc_status,
  move_in_date, monthly_rent_paise
) values (
  '77777777-7777-7777-7777-777777777777', '33333333-3333-3333-3333-333333333333',
  '55555555-5555-5555-5555-555555555555', 'Fake Tenant Pending', '+919876500002',
  'firebase-tenant-pending', 'active', 'submitted', '2026-02-01', 1000000
);

-- Tenant C: moved out — no access at all, even though KYC was approved while active.
insert into public.tenants (
  id, property_id, room_id, full_name, phone, firebase_uid, status, kyc_status,
  move_in_date, monthly_rent_paise
) values (
  '88888888-8888-8888-8888-888888888888', '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444', 'Fake Tenant Moved Out', '+919876500003',
  'firebase-tenant-movedout', 'moved_out', 'approved', '2025-06-01', 1000000
);

insert into public.kyc_submissions (
  id, tenant_id, status, aadhaar_last4, aadhaar_path, selfie_path
) values (
  'c7777777-7777-7777-7777-777777777777', '77777777-7777-7777-7777-777777777777',
  'submitted', '1234',
  '77777777-7777-7777-7777-777777777777/c7777777-7777-7777-7777-777777777777/aadhaar.jpg',
  '77777777-7777-7777-7777-777777777777/c7777777-7777-7777-7777-777777777777/selfie.jpg'
);

insert into public.dues (id, tenant_id, type, description, amount_paise, due_date, status, created_by)
values (
  'd6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666',
  'rent', 'September rent', 1000000, '2026-09-05', 'unpaid',
  'a1111111-1111-1111-1111-111111111111'
);
