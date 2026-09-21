# BalajiInfra

Hostel / PG management for India — tenant mobile app, admin web panel, and a
Supabase + Firebase backend. Full product and architecture rules live in
[`CLAUDE.md`](./CLAUDE.md); read that first.

## Repository layout

```
/
├── package.json  Root tooling only — holds the Supabase CLI devDependency
├── admin/        React + TypeScript admin panel (Vite, static SPA)
├── app/          Flutter mobile app                                        [pending — see below]
└── supabase/     Supabase CLI project (migrations, functions, pgTAP tests)
```

`app/` is not scaffolded yet — it requires the Flutter SDK, which isn't part of
this repo. See "Status" below.

## Status

- ✅ **admin/** — scaffolded (Vite + React 19 + TypeScript, Tailwind v4, shadcn/ui,
  TanStack Query/Table, React Router, react-hook-form + zod, Supabase JS client).
  Phase 2 (auth + MFA, protected layout, properties/rooms, tenant list/add/edit/move-out)
  built and verified end-to-end against the local stack (real login, real TOTP
  enrollment/verification, RLS-driven owner/staff UI differences).
- ✅ **supabase/** — scaffolded (`supabase init`). Hosted project (Mumbai) is
  connected via the Supabase GitHub integration — merges to `main` auto-deploy
  migrations to production, so treat any PR touching `supabase/migrations/` as a
  production change.
- ⏳ **app/** — pending, paused. Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
  installed locally, then `flutter create app` (existing Flutter code will be moved in).

## Local setup — admin panel

```
cd admin
npm install
cp .env.example .env.local   # fill in your Supabase project URL + anon key
npm run dev
```

**During development, `admin/.env.local` must point at the local Supabase instance
(`http://127.0.0.1:54321` + the local anon key printed by `npx supabase start`), never
the hosted project** — `admins` rows and MFA factors are per-project, so testing against
hosted from a dev machine would touch real (or at least production-adjacent) auth state.
`.env.local` is gitignored; there's nothing stopping it from pointing at hosted, so this
is a habit, not something enforced by tooling.

Other scripts: `npm run typecheck`, `npm run lint`, `npm run format:check`,
`npm run test`, `npm run build`. All of these run in CI on every push/PR that
touches `admin/` (see `.github/workflows/admin.yml`).

## Local setup — supabase

The Supabase CLI is **not** installed globally — it's a root `devDependency`,
invoked via `npx`:

```
npm install                 # installs the Supabase CLI (root package.json)
npx supabase start          # requires Docker Desktop running
npx supabase status
npx supabase stop
```

Requires [Docker Desktop](https://www.docker.com/products/docker-desktop/) running
locally. If `docker`/`npx supabase start` can't find Docker even though Docker
Desktop is running, its CLI usually isn't on `PATH` — add Docker Desktop's
`resources\bin` directory (check where Docker Desktop is actually installed; on
Windows this can be a per-user install under `%LOCALAPPDATA%\Programs\DockerDesktop`
rather than `Program Files`) to your `PATH` and restart your terminal.

Local URLs after `npx supabase start`: Studio at `http://127.0.0.1:54323`, API at
`http://127.0.0.1:54321`, Postgres at `127.0.0.1:54322`.

### Configuring the Firebase project id

Tenant RLS policies (`is_tenant()`) check the JWT's `iss`/`aud` claims against the
Firebase project id — this is **not hardcoded** in any function. It's a single row,
`app_config.key = 'firebase_project_id'`, read by `_firebase_project_id()`. A second,
separate copy of the same id configures Supabase Auth's own third-party Firebase
provider (`supabase/config.toml`, `[auth.third_party.firebase].project_id`) — this one
is required just to run `npx supabase start` at all:

```
cp .env.example .env   # repo root, NOT supabase/.env — see comments in .env.example
```

Supabase CLI's `env(...)` substitution in `config.toml` reads from a `.env` file at the
**project root** (docs: Local Development → Managing config), not from inside
`supabase/`. If this file is missing, `npx supabase start` does **not** fail with a clear
config error — it silently substitutes the literal text `env(SUPABASE_AUTH_FIREBASE_PROJECT_ID)`
into the config, which then fails later in a confusing way (e.g. a "Failed to fetch"
error on a URL containing that literal string). Always copy `.env.example` before running
any `npx supabase` command. CI sets the same fake default as a workflow env var instead
of checking in a `.env` (`.github/workflows/supabase.yml`).

- **Local / tests**: `supabase/seed.sql` sets `app_config.firebase_project_id` to the
  fake value `balajiinfra-local-dev` (applied automatically by `supabase start`/`db
  reset`) — matching the default in `.env.example`. pgTAP tests mock tenant JWTs with
  matching `aud`/`iss` claims, so don't change this default without also updating every
  test in `supabase/tests/`. To test a **real** Firebase OTP login against local
  Supabase, set `SUPABASE_AUTH_FIREBASE_PROJECT_ID` in `.env` to your real Firebase
  project id, restart `supabase start`, then sync `app_config` to match (command
  documented above the `app_config` update in `supabase/seed.sql`) — pgTAP tests will
  fail until you revert both.
- **Hosted**: started as JSON `null` (fail-closed — Firebase tenant login simply
  doesn't work until this is set, rather than trusting an unconfigured issuer). Set
  **once** the Firebase project existed (a human task, see `CLAUDE.md` §8), directly
  against the hosted database (Studio SQL editor), never as a migration:
  ```sql
  update public.app_config set value = '"<real-firebase-project-id>"'::jsonb
  where key = 'firebase_project_id';
  ```
  This is a data change, not a schema change — it stays out of migrations because a
  migration file applies identically to every environment (local and hosted both run
  the exact same SQL), so a value written into one would be the same value everywhere,
  defeating the point of an environment-specific setting. (Migrations themselves each
  run exactly once per database, tracked in Supabase's migration history — they don't
  re-run on later deploys.)

  **`app_config` is readable by `anon`** — never put a secret in it. API keys, webhook
  signing secrets, etc. go through `supabase secrets set`, never a table.

## Admin operations

### An admin lost their MFA device — removing their factor so they can re-enroll

There's no in-app UI for this (owners manage this out-of-band, not through the admin
panel itself). The admin panel has no signup — an admin's account already exists, so
"lost 2FA" means their next login gets stuck at the `/mfa/verify` challenge with no way
forward. An owner needs to delete their TOTP factor so the next login routes them to
enrollment instead.

- **Supabase Studio (recommended)**: Authentication → Users → find the admin by email →
  their MFA factors are listed on the user detail page → delete the factor. (Local:
  `http://127.0.0.1:54323`. Hosted: the project's dashboard.)
- **SQL fallback**, if Studio's UI doesn't expose it (run in the Studio SQL editor, which
  connects as `postgres` and bypasses RLS — this is not something to expose through the
  app itself):
  ```sql
  delete from auth.mfa_factors where user_id = (
    select id from auth.users where email = 'the-admin@example.com'
  );
  ```
  Their next login attempt will find no enrolled factor and land on the enrollment
  screen automatically — no other cleanup needed.

## Local setup — app (pending)

Not available yet — see "Status" above.

## Deployment — admin panel

`admin/` deploys to **Cloudflare Workers static assets** — not Cloudflare Pages. (Pages'
SPA fallback works via a `_redirects` file; Workers static assets uses
`assets.not_found_handling` in `admin/wrangler.jsonc` instead — mixing the two approaches
causes a deploy-time "infinite loop" error, since Pages' `/* /index.html 200` rule doesn't
mean the same thing to the Workers assets router.)

- Config: `admin/wrangler.jsonc` — static assets only (`assets.directory: "./dist"`,
  `assets.not_found_handling: "single-page-application"`), no Worker script.
- Deployed from `main` only.
- `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` are set as Cloudflare environment
  variables (Production), never committed — same rule as local `.env.local`. They're
  baked in at build time (Vite convention), so they must be set before the build runs.
- `wrangler` is a pinned (exact-version) `admin/` devDependency, not installed ad hoc, so
  `npx wrangler deploy` always uses the same version.
- Placed behind Cloudflare Access (separate from and in addition to the app's own
  Supabase Auth + MFA).

## Contributing

- Schema changes only via Supabase CLI migrations — never edit tables directly
  in the dashboard.
- Every RLS policy needs a pgTAP test proving both the allowed and denied case.
- No secrets in Git. Each package keeps a `.env.example` with placeholder names;
  real values go in a gitignored `.env` / `.env.local`.

See [`CLAUDE.md`](./CLAUDE.md) for the full set of rules and the phase-by-phase
build order.
