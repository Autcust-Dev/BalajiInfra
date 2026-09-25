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

1. Tenants are created one of two ways, never any other: **(a) an admin adds them**
   directly (name, phone, room, rent), or **(b) they self-register** through the app's
   sign-up flow (property → floor → sharing type → available room/bed → pricing →
   phone OTP → Razorpay payment) — but even then, the `tenants` row is created **only**
   by the payment webhook (or an admin completing a booking with a manual payment)
   on confirmed payment, never by client-side success or any other insert path. A
   self-registered tenant is identical in the database to an admin-added one — same
   columns, same triggers, same downstream rules. Before payment, a signup attempt is
   a `bookings` row, not a tenant, and no phone can log in until a `tenants` row for
   it exists (rule 2 is unchanged).
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
├── firebase/     Firebase Cloud Functions (2nd gen) — currently just the beforeSignIn
│                 blocking function that sets the `role: "authenticated"` custom claim
│                 (CLAUDE.md §4 rule 14). Deploy via `npx firebase-tools`, not this repo's
│                 root Supabase CLI devDependency.
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
- **Manual/dev testing targets the hosted project directly**, not `supabase start` — local
  Docker is too slow on Windows for iterative testing. This is only safe pre-launch, while
  the hosted project has no real tenant or KYC data. CI is unaffected: it still runs
  `supabase start` + pgTAP against local Docker on GitHub Actions
  (`.github/workflows/supabase.yml`), so nothing merges without passing there regardless of
  how it was tested locally. **Before any real tenant or KYC data goes into the hosted
  project, stand up a separate staging Supabase project** for manual/dev testing instead
  (Phase 6) — don't keep testing against hosted once it holds real data.

**Firebase**
- Firebase Phone Auth — **tenants only**. Connected to Supabase via Supabase
  "Third-party auth" (Firebase provider).
- Firebase Cloud Functions (2nd gen), region `asia-south1`, in `firebase/functions/` —
  currently just the `beforeSignIn` blocking function (rule 14). Requires the project to be
  upgraded to **Identity Platform** plus **Blaze billing** (already required for FCM/App
  Check) before it can be deployed.
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
14. Supabase third-party auth with Firebase **requires** a `role: authenticated` custom
    claim on Firebase tokens — confirmed against current Supabase docs (not just "may").
    Set via a Firebase Auth blocking function (2nd gen, `beforeSignIn`), scaffolded at
    `firebase/functions/src/index.ts` — sets `role: "authenticated"` and nothing else (no
    other claims, no secrets, no network calls). Not yet deployed: it needs Identity
    Platform + Blaze on the Firebase project first (`firebase/README.md`, and §8's "tasks
    only the human can do"). `supabase/tests/013_anon_role_blocked_without_authenticated_claim.sql`
    proves what happens without the claim — the session stays Postgres role `anon`, and
    every tenant-facing table's GRANT (rule 9) blocks it outright, independent of RLS.
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
22a. **Abandoned bookings** (self-signup attempts that never became a tenant — expired,
    cancelled, or failed) are auto-deleted after `app_config.booking_pii_retention_days`
    (default 90, admin-configurable) by a scheduled job
    (`public.delete_abandoned_bookings()`, pg_cron). A booking with `created_tenant_id`
    set, or with status `paid`/`refunded`, is a financial record and is **never**
    auto-deleted, enforced in the delete job's own `WHERE` clause, not by convention.

### Payments
23. The **amount is always computed server-side** — from the `dues` row for an existing
    tenant's payment, or from the `bookings` row's own snapshotted total for a signup
    payment (itself copied from `pricing_plans` at hold time, so a later price edit never
    changes an in-flight or completed booking). The client only ever sends an id, never
    an amount. The webhook re-verifies the amount actually paid against that
    server-held total before creating anything — a mismatch is rejected, not adjusted.
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

### Deferred (post-launch, not forgotten)
- **Forward-dated availability**: letting a bed be booked for a date after an existing
  tenant's *scheduled* (not yet actual) move-out, so a new tenant can be lined up before
  the room is physically empty. Explicitly deferred — agreed post-launch, not before.
  What it would take when the time comes: bed occupancy today is a flat "occupied now or
  not," not an interval — this needs a real `scheduled_move_out_date` distinct from the
  actual `move_out_date` (tenant stays `active` until the real event), `bed_is_available()`
  becoming date-parameterized with interval-overlap logic instead of a snapshot boolean,
  bookings/holds carrying a target move-in date, a seat-map UX for "available from
  `<date>`," and a product decision on what happens if the current tenant doesn't actually
  leave on time. Additive on top of what's built for launch — nothing already shipped
  needs reworking to add this later.

---

## 5. Core data model (initial)

Create in migration order; adjust names only with good reason and update this file.

- `admins` — user_id (→ auth.users), name, role (`owner | staff`), active.
- `properties` — name, address, code (2 uppercase letters, auto-generated from the name
  on insert, unique, admin-editable if the generated one collides or an admin just wants
  to change it — a later change only affects tenant_codes assigned from then on, never
  rewrites already-issued ones), self_signup_enabled (per-property opt-in for self-signup).
- `floors` — property_id, name, display_order.
- `blocks` — floor_id, name, display_order.
- `rooms` — property_id, room_number, block_id (nullable). A pure location shell — sharing
  type and capacity live one level down, on `room_units`.
- `room_units` — room_id, capacity. A room may have up to one unit each of single/double/
  triple (etc.) sharing; each unit is its own occupancy group and its own electricity-bill
  split, independent of whatever other units exist in the same room.
- `beds` — room_unit_id, bed_label, under_maintenance. One row per unit of capacity,
  auto-provisioned when a room_unit is created. Powers the app's seat map (a room's beds
  shown as selectable/grayed-out) via `tenants.bed_id` below and self-signup holds via
  `bookings.bed_id`. `under_maintenance` is the only stored state — it's the one thing
  genuinely not derivable from bookings/tenants; everything else (held, occupied,
  available) is computed live by `bed_is_available(bed_id)`, the single canonical
  availability function every caller (admin panel, Edge Functions, pgTAP) uses rather
  than re-implementing the same logic — never a denormalized status flag that could drift.
- `tenants` — property_id, room_unit_id, bed_id (nullable — see note), tenant_code
  (nullable — see note), full_name, phone (E.164, unique), firebase_uid (nullable, unique,
  set on first login — or set immediately at creation for a self-registered tenant, since
  their phone was already OTP-verified pre-payment), status (`active | moved_out`),
  kyc_status (enum), move_in_date, move_out_date, monthly_rent_paise, billing_cycle
  (`monthly | yearly`), fcm_token. At most one active tenant per bed, enforced by a
  partial unique index on bed_id, and bed_id must belong to the tenant's own
  room_unit_id, enforced by trigger. `bed_id` is nullable because it was added after
  tenants already existed: a migration backfilled it for every existing active tenant
  where a clean 1:1 room_unit→bed assignment was possible, but any tenant in a room_unit
  an admin had already put over capacity (via the tenant form's capacity-override
  warning) couldn't be assigned one and needs a manual admin fix — the tenant form must
  surface "no bed assigned" for these. Going forward, both the tenant form and the
  self-signup webhook are expected to always set it.

  `tenant_code` is the human-readable id (`<PROPERTY_CODE>-<FULL_YEAR>-<SEQUENCE>`, e.g.
  `SE-2026-0001` — the full 4-digit year is stored, not a 2-digit shorthand, so it never
  collides or breaks after 2099; a shorter display form, if ever wanted on an invoice
  template, is that screen's own rendering choice, not a second stored value),
  unique, shown to the tenant in the app and searchable/printed in the admin panel.
  Assigned automatically by a `before insert` trigger via `tenant_code_sequences`
  (property_id, year, next_sequence) — a dedicated counter table whose row-locked UPSERT
  is what actually guarantees "assigned by the database, never reused, race-safe between
  an admin insert and a self-signup webhook," not application-level retry logic.
  Deliberately excludes floor/room/sharing type — a tenant's room can change, and an id
  encoding it would go stale or force reissuing; the current room is shown next to the id
  in the UI instead. `tenant_code` is nullable for the same reason `bed_id` is: a
  property whose auto-generated code collided and was never manually fixed can't be
  backfilled — but unlike `bed_id`, a missing code must **never** block creating the
  tenant (most importantly: a self-signup tenant who already paid cannot fail to become
  a tenant over something unrelated to them), so the trigger just leaves `tenant_code`
  null rather than raising. Both this and a missing `bed_id` are surfaced to admins the
  same way (PR4). Property-code collisions are expected to be common (e.g. "Balaji
  Executive" / "Balaji Elite" both generate `BE`) — **PR4 must make the admin property
  form require a code at creation time**, suggesting the auto-generated one and
  rejecting a duplicate with a clear message, rather than leaving this to be discovered
  as a silent null later.
- `consents` — tenant_id, policy_version, typed_full_name, accepted_at, app_version,
  device_info.
- `kyc_submissions` — tenant_id, status, aadhaar_last4, aadhaar_path, selfie_path,
  submitted_at, reviewed_by (→ admins), reviewed_at, rejection_reason.
  `tenants.kyc_status` kept in sync by trigger (including on delete/resubmission).
- `dues` — tenant_id, type (`rent | deposit | electricity | other`), description,
  amount_paise, due_date, status (`unpaid | paid | cancelled`), created_by.
- `fines` — due_id, amount_paise, starts_on, ends_on, created_by. A flat admin-entered
  amount, not a calculated rate; a due's true total is `dues.amount_paise + sum(fines)`.
- `electricity_bills` — room_unit_id, billing_period, total_amount_paise, created_by. One
  per unit per month; auto-split across that unit's active tenants (frozen once paid or on
  move-out) into `electricity_bill_splits` (bill_id, tenant_id, due_id — pure junction, no
  duplicated amount).
- `payments` — due_id, tenant_id, amount_paise, source (`razorpay | manual`),
  status (`created | paid | failed | refunded`), razorpay_order_id (unique),
  razorpay_payment_id (unique), method, paid_at, recorded_by.
- `pricing_plans` — property_id, capacity (sharing type), security_deposit_paise,
  rent_monthly_paise, rent_yearly_paise, onboarding_charges_paise, active.
  Admin-editable; a booking snapshots these onto itself at hold time so a later edit
  never changes an in-flight or completed booking.
- `bookings` — the pre-tenant self-signup lifecycle (property_id, room_unit_id, bed_id,
  full_name, phone, status (`hold | otp_verified | payment_pending | paid |
  payment_failed | expired | cancelled | refunded`), billing_cycle, snapshotted pricing,
  held_expires_at, razorpay_order_id/payment_id, source (`self_signup | manual`),
  created_tenant_id, recorded_by). At most one active (`hold|otp_verified|
  payment_pending`) booking per bed and per phone, enforced by a partial unique index —
  the actual double-booking guard, not application logic. The `tenants` row is created
  only when a booking reaches `paid` (rule 1). No anon/authenticated access — reached only
  through service_role Edge Functions (and directly by admins, for the Bookings/Leads
  page and manual-payment completion). The app's seat map and the `list-availability`
  response must never expose an occupant's name or any other tenant detail — only a bed
  label and whether `bed_is_available()` says it's selectable; that function returns a
  single boolean by design, so there's nothing to leak even if its result is inspected.
- `whatsapp_invoice_log` — booking_id, status (`pending | sent | failed`),
  provider_message_id, error_message. Fire-and-forget from the payment webhook; the in-app
  invoice is the source of truth regardless of WhatsApp delivery.
- `webhook_events` — provider, event_id (unique), payload, processed_at.
- `audit_log` — actor_type, actor_id, action, table_name, row_id, before, after, at.
- `app_config` — key/value (min_app_version, current policy_version,
  booking_pii_retention_days, etc.).

---

## 6. CI (GitHub Actions) — must pass before merge

- `supabase`: start local stack, apply migrations, run pgTAP tests.
- `admin`: install, `tsc --noEmit`, lint, build, unit tests.
- `app`: `flutter analyze` (zero issues), `flutter test`.
- `firebase-functions`: install, `tsc --noEmit`, unit tests (`firebase/functions/`). Build
  only — CI never deploys it (rule 14's blocking function is deployed manually, once).
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
`beforeSignIn` blocking function (rule 14) scaffolded in `firebase/functions/` — deploy is
a human-only step gated on Identity Platform + Blaze (§8), so login only fully works
end-to-end on hosted once that's done.

**Phase 4 — KYC end to end**
App: consent screen → masked Aadhaar upload → in-app selfie → submit → pending screen
with Realtime + FCM + resume check. Admin: KYC review queue, signed-URL image viewer,
approve / reject with reason. Push notification on decision.

**Phase 5 — Payments**
Admin: create dues, record manual payments, payment history. Edge Functions:
`create-order`, `razorpay-webhook`. App: dues list, pay via Razorpay, receipts.

**Phase 6 — Hardening and release**
Error states, offline handling, empty states, Sentry/Crashlytics, rate limits review,
security review of every policy and function, store release checklists. **Stand up a
separate staging Supabase project before any real tenant or KYC data goes into the hosted
(production) project** — manual/dev testing has been happening directly against hosted
pre-launch (§3) since local Docker is too slow on Windows; that stops being safe once real
data exists, so move dev/manual testing to staging at that point instead. **Enforce Firebase
App Check** before release: switch from debug providers to Play Integrity (Android) /
App Attest (iOS) and turn on enforcement for the OTP endpoint (per §3, App Check protects
`check-phone` from SMS abuse — debug-provider tokens must not be accepted in production).
Register the **release SHA-1/SHA-256** (and, once Play App Signing re-signs the app, the
**Play App Signing certificate's** SHA-1/SHA-256 pulled from Play Console → Setup → App
Integrity) in the Firebase Android app's settings, alongside the debug fingerprint added in
Phase 3. Restrict the Android `google-services.json` API key in Google Cloud Console →
Credentials to this package name (`com.balajiinfra.hostels`) + the registered SHA-1
fingerprints, once all the release ones are known.

---

## 8. How to work

- Before a phase: write a short plan (files to create/change, migrations, tests) and
  show it to the human. Then implement.
- Small, focused commits with clear messages. One concern per commit.
- **All changes go through a branch + pull request; `main` is never pushed to or merged
  into directly.** The human merges PRs on GitHub — never via the IDE's "Commit & Sync"
  (or any local push straight to `main`) and never via an in-editor merge into `main`.
  This applies to the coding agent too: always work on a branch and open a PR, never
  commit or push directly to `main`. Reason: `main` auto-deploys — every migration
  merged to it is applied to the live hosted Supabase database, and `admin/` deploys to
  production from it (§3) — so a direct/local merge into `main` ships to production
  with no review step.
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
- Upgrade the Firebase project to Identity Platform (Authentication → Settings →
  "Upgrade to Identity Platform") — required before the `beforeSignIn` blocking function
  (rule 14) can be deployed.
- Deploy the `beforeSignIn` blocking function once Blaze + Identity Platform are on:
  `npx firebase-tools deploy --only functions:beforeSignIn --project balajiinfraandhostel`
  from `firebase/` (see `firebase/README.md`).
- Configure Supabase third-party auth (Firebase) in the dashboard if CLI can't.
- Razorpay account, KYC with Razorpay, API keys, webhook secret.
- Apple Developer + Google Play accounts.
- Cloudflare Workers (static assets) project and Cloudflare Access policy for the admin site.
- Legal review of privacy policy and consent text.
