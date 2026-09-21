# CLAUDE.md — Project Instructions for the Coding Agent

Read this file fully at the start of every session. It is the source of truth for
architecture, rules, and build order. If a decision here changes, update this file
in the same commit.

---

## 1. Product

A hostel / PG management product for India, with three parts:

- **Mobile app (tenants)** — iOS + Android.
- **Admin panel (web)** — used by hostel admins.
- **Backend** — Supabase (Mumbai region) + Firebase (phone OTP, push only).

Core rules of the product:

1. Tenants **cannot self-register**. An admin adds the tenant (name, phone, room, rent)
   first. Only phone numbers that exist in the `tenants` table can log in.
2. Login = phone number → OTP (Firebase Phone Auth) → session.
3. After first login, **KYC is mandatory** before any other screen:
   privacy-policy consent + typed full name (as on Aadhaar) → masked Aadhaar upload →
   live selfie (in-app camera only) → submit → "pending review" screen.
4. An admin reviews the KYC in the admin panel and **approves or rejects with a reason**.
   Rejected → tenant re-uploads. Approved → the app unlocks the main screen
   **within about a second**, without the user refreshing.
5. Admins add rent/charges and record manual (cash/UPI) payments. Tenants can pay online
   via Razorpay.

---

## 2. Repository layout (monorepo)

```
/
├── CLAUDE.md
├── package.json  Root tooling only — holds the Supabase CLI devDependency
├── app/          Flutter mobile app
├── admin/        React + TypeScript admin panel (Vite, static site)
├── supabase/     Supabase CLI project (run via `npx supabase` from repo root)
│   ├── migrations/   SQL migrations (ONLY way to change the schema)
│   ├── functions/    Edge Functions (TypeScript / Deno)
│   ├── tests/        pgTAP database tests (RLS + constraints)
│   └── seed.sql      Local dev seed data (fake data only)
└── .github/workflows/  CI
```

---

## 3. Stack (do not substitute without updating this file)

**Backend — Supabase**
- PostgreSQL with Row Level Security (RLS) on every table.
- Storage: private buckets only, access via short-lived signed URLs.
- Realtime: KYC status changes → app.
- Edge Functions (TypeScript): Razorpay, admin-privileged operations, anything that
  needs a secret key.
- Supabase Auth (email + password + **TOTP MFA required**) — **admins only**.
- Hosted project (Mumbai) is connected to this repo via the Supabase GitHub integration
  (production branch `main`, deploy-to-production **on**). Every migration merged to
  `main` is applied to the live database automatically — get explicit human confirmation
  before merging a migration-bearing change.
- **Supabase CLI is a root `devDependency`** (`npm install supabase --save-dev` at the
  repo root), invoked as `npx supabase <command>` from the repo root — not a global
  install. Requires Docker Desktop running locally for `supabase start`.

**Firebase**
- Firebase Phone Auth — **tenants only**. Connected to Supabase via Supabase
  "Third-party auth" (Firebase provider).
- Firebase Cloud Messaging (FCM) — push notifications.
- Crashlytics — app crash reporting.
- App Check enabled (protects the OTP endpoint from SMS abuse).

**Mobile — Flutter (Dart)**
- State: Riverpod. Navigation: go_router. Models: freezed + json_serializable.
- Packages: supabase_flutter, firebase_core, firebase_auth, firebase_messaging,
  firebase_crashlytics, camera, an image-compression package.
- Lints: very strict (`flutter_lints` + stricter rules). Zero analyzer warnings.

**Admin panel — React + TypeScript (Vite, static SPA)**
- UI: shadcn/ui + Tailwind. Tables: TanStack Table. Data: TanStack Query.
  Routing: React Router. Forms: react-hook-form + zod.
- Client: `@supabase/supabase-js` with generated types.
- Hosting: **Cloudflare Workers static assets** (not Cloudflare Pages — Pages' `_redirects`
  SPA-fallback approach isn't how this deploys; Workers uses `assets.not_found_handling =
  "single-page-application"` in `admin/wrangler.jsonc` instead). Static assets only, no
  Worker script, deployed from `main` only. Placed behind **Cloudflare Access**.
- No server code in `admin/`. Anything privileged goes through an Edge Function.

**Payments** — Razorpay, called only from Edge Functions.

**Monitoring** — Crashlytics (app), Sentry (admin + Edge Functions).

When using any external API or SDK (Supabase, Firebase, Razorpay, Flutter packages),
**check the current official docs before writing code**. APIs and requirements change.
Never invent method names, config keys, or claims.

---

## 4. Non-negotiable rules

### Schema and data
1. **Schema changes only through migrations** in `supabase/migrations/`, created with
   the Supabase CLI. Never tell the human to edit tables in the dashboard.
2. **Additive changes only.** Add columns/tables freely. Never rename or drop a column
   the mobile app uses in the same release. Breaking changes follow:
   add new → ship app update → raise `min_app_version` → remove old later.
3. After every migration: regenerate TypeScript types
   (`supabase gen types typescript`) into `admin/src/types/` and
   `supabase/functions/_shared/`, and update matching Dart models in `app/`.
4. Shared status values are **Postgres enums**, used identically everywhere
   (e.g. `kyc_status`: `not_started | submitted | approved | rejected`).
5. All timestamps are `timestamptz` stored in **UTC**. Convert to IST only in UI.
6. Money is stored as **integer paise** (`amount_paise bigint`). Never floats.
7. Phone numbers are stored in **E.164** (`+919876543210`), normalized on write.
8. Every table: `id uuid primary key default gen_random_uuid()`, `created_at`,
   `updated_at` (trigger-maintained).

### Security
9. **RLS enabled on every table**, with explicit policies. No table without policies.
   The hosted Supabase project has the **Data API enabled**, **"automatically expose new
   tables" disabled**, and **automatic RLS enabled** at the project level. Migrations must
   not rely on those dashboard defaults, or on whatever the local CLI defaults to — each
   migration must be correct on its own, matching the hosted project exactly:
   - Every table's creation migration includes an explicit
     `ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;`.
   - Every table gets explicit `GRANT` statements to `anon` and/or `authenticated`, limited to
     only the operations (`SELECT` / `INSERT` / `UPDATE` / `DELETE`) that role actually needs.
     Never `GRANT ALL`. RLS policies then further restrict which rows are visible/writable.
   - Internal-only tables — `audit_log`, `webhook_events`, and any future table with no direct
     client access — get **no grants to `anon` or `authenticated` at all**. Only `service_role`
     (used exclusively in Edge Functions) reads/writes them; `service_role` bypasses RLS and
     grants by default, so no grant is needed for it.
10. **Every RLS policy has pgTAP tests** proving both the allowed and the denied case
    (tenant A cannot read tenant B; tenant cannot approve KYC; non-admin cannot read
    KYC files; etc.). A policy without tests is not done.
11. The **service_role key never appears in `app/` or `admin/`.** Only Edge Functions
    use it, read from Supabase secrets.
12. No secrets in Git. Use `.env` files (gitignored) + `.env.example` with placeholder
    names. Supabase secrets via `supabase secrets set`.
13. Tenant identity: Firebase UIDs are **not UUIDs**. Never use `auth.uid()` for
    tenants — use `auth.jwt() ->> 'sub'` and `auth.jwt() ->> 'phone_number'`.
    (`auth.uid()` itself force-casts `sub` to `uuid`, which throws for a non-uuid Firebase
    `sub` — a real bug caught in Phase 1. `is_admin()` runs on every table's RLS check,
    including tables tenants query, so it must never call `auth.uid()` either; it goes
    through `_jwt_sub_as_uuid()`, which returns null instead of raising for a non-uuid
    `sub`.) Tenant policies must also check the token issuer is our Firebase project
    (`iss` / `aud`) — implemented in Phase 1 as `iss = https://securetoken.google.com/<id>`,
    `aud = <id>`, the standard raw-Firebase-ID-token shape. Put this logic in helper SQL
    functions (`is_tenant()`, `current_tenant_id()`, `is_admin()`), `security definer`,
    `stable`, with a fixed `search_path`.

    The Firebase project id itself is **not hardcoded anywhere** — it's the single row
    `app_config.key = 'firebase_project_id'`, read by `_firebase_project_id()`. Starts as
    JSON `null` (fail-closed: `is_tenant()` returns false for everyone until this is set).
    `supabase/seed.sql` overwrites it locally with a fake value for tests; the hosted value
    was set once via the Studio SQL editor after the Firebase project was created (§8).
    This must never be pushed as a migration — not because migrations re-run (a migration
    runs exactly once per database, tracked in Supabase's migration history table, never
    repeated on later deploys), but because the same migration file applies identically to
    *every* environment. A value written into a migration is the same value everywhere,
    which defeats the whole point of an environment-specific setting (fake locally, real on
    hosted). `app_config` is readable by `anon` — **never store secrets there**; secrets
    (API keys, webhook signing secrets, etc.) go through `supabase secrets set` (rule 12),
    never a table.
14. Supabase third-party auth with Firebase may require a `role: authenticated`
    custom claim on Firebase tokens (set via Firebase blocking function or Admin SDK).
    **Verify current Supabase docs and implement exactly what they require.**
    If this proves unworkable, stop and propose the fallback (an Edge Function that
    verifies the Firebase ID token and issues a Supabase-compatible JWT) to the human.
15. Admins: Supabase Auth user + row in `admins` table + MFA (`aal2`) required by
    `is_admin()`. Admin creation is manual/seeded, never self-signup
    (disable public signups).
16. **Audit log**: every admin write (tenant create/edit, KYC approve/reject,
    payment record) writes to `audit_log` via database triggers — actor, action,
    table, row id, before/after JSON, timestamp. Admin viewing a KYC file is logged
    by the Edge Function that issues the signed URL.

### KYC and privacy (India: Aadhaar + DPDP Act)
17. Accept **masked Aadhaar only** (first 8 digits hidden). Store only
    `aadhaar_last4`. Never store, log, display, or export a full Aadhaar number.
18. Selfie must be captured with the **in-app camera** — no gallery picker.
19. Compress images client-side before upload (target < 1 MB each, JPEG).
20. Storage bucket `kyc` is **private**. Path: `{tenant_id}/{submission_id}/{aadhaar|selfie}.jpg`.
    Tenants may upload only into their own folder and only while their submission is
    `not_started` or `rejected`. Admins get **signed URLs valid ≤ 60 seconds** from an
    Edge Function (which writes the audit log). No public URLs, ever.
21. Consent record: policy version, typed full name, accepted_at, app version, device
    info. Checkbox is **never pre-ticked**. Consent row must exist before any upload.
22. Never log personal data (names, phones, images, tokens) to console, Sentry, or
    Crashlytics.

### Payments
23. The **amount is always computed server-side** from the `dues` row. The client
    only sends the due id.
24. Flow: app → Edge Function `create-order` → Razorpay order → Razorpay checkout in
    app → Edge Function `razorpay-webhook` marks the payment paid.
    The webhook is the source of truth; the client-side success callback only shows UI.
25. Verify the webhook signature (HMAC with webhook secret) on every request.
26. **Idempotent**: unique constraints on `razorpay_order_id`, `razorpay_payment_id`,
    and a `webhook_events` table keyed by event id. Processing the same event twice
    must change nothing.
27. Manual payments: recorded by an admin, `source = 'manual'`, `recorded_by` set,
    audited.

### App behaviour
28. Route guard order: not logged in → login; no consent → consent; KYC not approved
    → KYC / pending screen; approved → main app. Enforced in go_router redirect AND
    in RLS (the backend must refuse main-app data to non-approved tenants).
29. KYC unlock: Realtime subscription on the tenant's own KYC status **plus** an FCM
    push **plus** a status re-check on app start/resume. All three.
30. `app_config` table with `min_app_version` (android/ios). App checks on start;
    if too old → blocking "Please update" screen with store link.
31. Before sending an OTP, call Edge Function `check-phone` (rate-limited per IP and
    per phone). Response is only `{ allowed: boolean }`. Never reveal tenant details.

---

## 5. Core data model (initial)

Create in migration order; adjust names only with good reason and update this file.

- `admins` — user_id (→ auth.users), name, role (`owner | staff`), active.
- `properties` — name, address (support multiple hostels from day one).
- `rooms` — property_id, room_number, capacity.
- `tenants` — property_id, room_id, full_name, phone (E.164, unique), firebase_uid
  (nullable, unique, set on first login), status (`active | moved_out`),
  kyc_status (enum), move_in_date, monthly_rent_paise, fcm_token.
- `consents` — tenant_id, policy_version, typed_full_name, accepted_at, app_version,
  device_info.
- `kyc_submissions` — tenant_id, status, aadhaar_last4, aadhaar_path, selfie_path,
  submitted_at, reviewed_by (→ admins), reviewed_at, rejection_reason.
  `tenants.kyc_status` kept in sync by trigger.
- `dues` — tenant_id, type (`rent | deposit | electricity | other`), description,
  amount_paise, due_date, status (`unpaid | paid | cancelled`), created_by.
- `payments` — due_id, tenant_id, amount_paise, source (`razorpay | manual`),
  status (`created | paid | failed | refunded`), razorpay_order_id (unique),
  razorpay_payment_id (unique), method, paid_at, recorded_by.
- `webhook_events` — provider, event_id (unique), payload, processed_at.
- `audit_log` — actor_type, actor_id, action, table_name, row_id, before, after, at.
- `app_config` — key/value (min_app_version, current policy_version, etc.).

---

## 6. CI (GitHub Actions) — must pass before merge

- `supabase`: start local stack, apply migrations, run pgTAP tests.
- `admin`: install, `tsc --noEmit`, lint, build, unit tests.
- `app`: `flutter analyze` (zero issues), `flutter test`.
- Fail the build if generated types are out of date with migrations.

---

## 7. Build order (work phase by phase; do not skip ahead)

Each phase ends with: all tests passing, CI green, a short summary to the human of what
was built, what to test manually, and anything the human must do.

**Phase 0 — Scaffold**
Monorepo folders, Supabase CLI init, Flutter project in `app/` (move existing code if
present), Vite React TS in `admin/`, lint/format configs, `.env.example` files,
CI workflows, README with local setup steps.

**Phase 1 — Database foundation**
All tables from section 5, enums, triggers (updated_at, kyc_status sync, audit log),
helper auth functions, RLS policies, storage bucket + storage policies, pgTAP tests
for every policy, seed data (fake tenants), generated types.

**Phase 2 — Admin panel: auth + tenants**
Admin login with MFA, protected layout, property/room management, tenant list
(search, filter, pagination), add/edit tenant, move-out.

**Phase 3 — App: login**
`check-phone` function, Firebase OTP flow, Supabase third-party auth wiring,
firebase_uid linking on first login, session persistence, logout, min-version check.

**Phase 4 — KYC end to end**
App: consent screen → masked Aadhaar upload → in-app selfie → submit → pending screen
with Realtime + FCM + resume check. Admin: KYC review queue, signed-URL image viewer,
approve / reject with reason. Push notification on decision.

**Phase 5 — Payments**
Admin: create dues, record manual payments, payment history. Edge Functions:
`create-order`, `razorpay-webhook`. App: dues list, pay via Razorpay, receipts.

**Phase 6 — Hardening and release**
Error states, offline handling, empty states, Sentry/Crashlytics, rate limits review,
security review of every policy and function, store release checklists. **Enforce Firebase
App Check** before release: switch from debug providers to Play Integrity (Android) /
App Attest (iOS) and turn on enforcement for the OTP endpoint (per §3, App Check protects
`check-phone` from SMS abuse — debug-provider tokens must not be accepted in production).

---

## 8. How to work

- Before a phase: write a short plan (files to create/change, migrations, tests) and
  show it to the human. Then implement.
- Small, focused commits with clear messages. One concern per commit.
- Write tests alongside code, not after.
- When a requirement is unclear, ask. Do not guess on anything involving money,
  personal data, or security.
- **Stop and ask the human** before: destructive migrations, anything touching legal /
  compliance wording (privacy policy text, consent text), adding a paid service,
  changing the stack, or anything requiring account access/secrets.

### Tasks only the human can do (list them when needed; never pretend to do them)
- Create Supabase project (region: Mumbai) and share project ref / keys securely.
- Create Firebase project, add Android + iOS apps, download config files, enable
  Phone Auth, Blaze billing with a budget alert, App Check.
- Configure Supabase third-party auth (Firebase) in the dashboard if CLI can't.
- Razorpay account, KYC with Razorpay, API keys, webhook secret.
- Apple Developer + Google Play accounts.
- Cloudflare Workers (static assets) project and Cloudflare Access policy for the admin site.
- Legal review of privacy policy and consent text.
