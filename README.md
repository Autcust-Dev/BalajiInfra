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

## Local setup — app (pending)

Not available yet — see "Status" above.

## Contributing

- Schema changes only via Supabase CLI migrations — never edit tables directly
  in the dashboard.
- Every RLS policy needs a pgTAP test proving both the allowed and denied case.
- No secrets in Git. Each package keeps a `.env.example` with placeholder names;
  real values go in a gitignored `.env` / `.env.local`.

See [`CLAUDE.md`](./CLAUDE.md) for the full set of rules and the phase-by-phase
build order.
