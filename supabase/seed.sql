-- Local dev / test seed data only. Fake data — never real tenant/PII data.
-- Fixed UUIDs throughout so pgTAP tests (supabase/tests/) can reference fixtures
-- deterministically without querying back generated ids.

-- Local-only override of the app_config-driven Firebase project id (see the comment on
-- this row in the app_config migration). This value never reaches the hosted database —
-- seed.sql only runs locally. Tests mock tenant JWTs with matching aud/iss claims
-- (supabase/tests/*.sql) against this exact literal — do not change it here, and do not
-- read it from an env var: plain SQL files can't see OS environment variables, and every
-- pgTAP test's "should succeed" case depends on this staying "balajiinfra-local-dev".
--
-- To test a real Firebase OTP login locally instead: set SUPABASE_AUTH_FIREBASE_PROJECT_ID
-- in .env AT THE REPO ROOT (see .env.example there — config.toml's env() reads from the
-- project root, not supabase/) to your real Firebase project id, then use
-- `npm run supabase:start` / `npm run db:reset` (not the bare `npx supabase` equivalents)
-- — both run scripts/sync-local-firebase-project-id.js right after this file seeds, which
-- brings app_config back in sync with .env from outside SQL (see README.md, "Configuring
-- the Firebase project id"). pgTAP tests will fail while .env is set this way, since their
-- mocked JWTs still say "balajiinfra-local-dev" — switch .env back and re-run
-- `npm run db:reset` before `npx supabase test db`.
update public.app_config
set value = '"balajiinfra-local-dev"'::jsonb
where key = 'firebase_project_id';

-- Two Supabase Auth users for the two admins below, real enough to actually log in with
-- via the Supabase JS client (not just pgTAP-mocked JWTs) — useful for manually exercising
-- the admin panel's login/MFA flow locally. The token/change columns below have no default
-- in the auth.users schema (they default to NULL), but GoTrue's Go driver can't scan NULL
-- into them — it expects '' — so every dashboard/signup-created user has them as '', and a
-- raw INSERT must set them explicitly too, or every login attempt 500s with "error finding
-- user: sql: Scan error ... converting NULL to string is unsupported" (caught locally by
-- actually driving the login page in a browser, not just pgTAP).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'owner@example.test', crypt('local-dev-only', gen_salt('bf')),
   now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}',
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'staff@example.test', crypt('local-dev-only', gen_salt('bf')),
   now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}',
   '', '', '', '');

insert into public.admins (id, user_id, name, role, active) values
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Fake Owner', 'owner', true),
  ('a2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'Fake Staff', 'staff', true);

insert into public.properties (id, name, address) values
  ('33333333-3333-3333-3333-333333333333', 'Fake PG Bangalore', '123 Fake Street, Bengaluru');

insert into public.rooms (id, property_id, room_number) values
  ('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', '101'),
  ('55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333', '102');

insert into public.room_units (id, room_id, capacity) values
  ('b4444444-4444-4444-4444-444444444444', '44444444-4444-4444-4444-444444444444', 2),
  ('b5555555-5555-5555-5555-555555555555', '55555555-5555-5555-5555-555555555555', 2);

-- A second, unrelated property/room with no tenants at all — purely so tests can prove a
-- tenant cannot read a property/room that isn't their own.
insert into public.properties (id, name, address) values
  ('99999999-9999-9999-9999-999999999999', 'Other Fake PG Chennai', '456 Other Street, Chennai');

insert into public.rooms (id, property_id, room_number) values
  ('e0000000-0000-0000-0000-000000000000', '99999999-9999-9999-9999-999999999999', '201');

insert into public.room_units (id, room_id, capacity) values
  ('be000000-0000-0000-0000-000000000000', 'e0000000-0000-0000-0000-000000000000', 2);

-- Tenant A: active, KYC approved — should have full main-app access (dues/payments).
insert into public.tenants (
  id, property_id, room_unit_id, bed_id, full_name, phone, firebase_uid, status, kyc_status,
  move_in_date, monthly_rent_paise
) values (
  '66666666-6666-6666-6666-666666666666', '33333333-3333-3333-3333-333333333333',
  'b4444444-4444-4444-4444-444444444444',
  (select id from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 1'),
  'Fake Tenant Approved', '+919876500001',
  'firebase-tenant-approved', 'active', 'approved', '2026-01-01', 1000000
);

-- Tenant B: active, KYC submitted but not yet approved — own row/consents/kyc only, no
-- dues/payments.
insert into public.tenants (
  id, property_id, room_unit_id, bed_id, full_name, phone, firebase_uid, status, kyc_status,
  move_in_date, monthly_rent_paise
) values (
  '77777777-7777-7777-7777-777777777777', '33333333-3333-3333-3333-333333333333',
  'b5555555-5555-5555-5555-555555555555',
  (select id from public.beds where room_unit_id = 'b5555555-5555-5555-5555-555555555555' and bed_label = 'Bed 1'),
  'Fake Tenant Pending', '+919876500002',
  'firebase-tenant-pending', 'active', 'submitted', '2026-02-01', 1000000
);

-- Tenant C: moved out — no access at all, even though KYC was approved while active.
insert into public.tenants (
  id, property_id, room_unit_id, full_name, phone, firebase_uid, status, kyc_status,
  move_in_date, move_out_date, monthly_rent_paise
) values (
  '88888888-8888-8888-8888-888888888888', '33333333-3333-3333-3333-333333333333',
  'b4444444-4444-4444-4444-444444444444', 'Fake Tenant Moved Out', '+919876500003',
  'firebase-tenant-movedout', 'moved_out', 'approved', '2025-06-01', '2026-06-01', 1000000
);

insert into public.kyc_submissions (
  id, tenant_id, status, aadhaar_last4, aadhaar_path, selfie_path
) values (
  'c7777777-7777-7777-7777-777777777777', '77777777-7777-7777-7777-777777777777',
  'submitted', '1234',
  '77777777-7777-7777-7777-777777777777/c7777777-7777-7777-7777-777777777777/aadhaar.jpg',
  '77777777-7777-7777-7777-777777777777/c7777777-7777-7777-7777-777777777777/selfie.jpg'
);

-- Tenant D: active, KYC not started, no firebase_uid yet — for manually testing a real
-- Firebase phone-auth login end to end (device/emulator + a Firebase "test phone number"
-- matching this row, see .env.example at the repo root). firebase_uid is intentionally
-- NULL: it
-- gets set by the link-firebase-uid Edge Function on this tenant's first real login, the
-- same as it would for a real tenant.
insert into public.tenants (
  id, property_id, room_unit_id, bed_id, full_name, phone, status, kyc_status,
  move_in_date, monthly_rent_paise
) values (
  'f2222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333',
  'b4444444-4444-4444-4444-444444444444',
  (select id from public.beds where room_unit_id = 'b4444444-4444-4444-4444-444444444444' and bed_label = 'Bed 2'),
  'Fake Tenant Login Test', '+919398252518',
  'active', 'not_started', '2026-09-01', 1000000
);

insert into public.dues (id, tenant_id, type, description, amount_paise, due_date, status, created_by)
values (
  'd6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666',
  'rent', 'September rent', 1000000, '2026-09-05', 'unpaid',
  'a1111111-1111-1111-1111-111111111111'
);
