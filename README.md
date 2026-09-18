# BalajiInfra

Hostel / PG management for India — tenant mobile app, admin web panel, and a
Supabase + Firebase backend. Full product and architecture rules live in
[`CLAUDE.md`](./CLAUDE.md); read that first.

## Repository layout

```
/
├── admin/        React + TypeScript admin panel (Vite, static SPA)
├── app/          Flutter mobile app                    [pending — see below]
├── supabase/     Supabase CLI project (migrations, functions, pgTAP tests)  [pending — see below]
└── .github/workflows/  CI
```

`app/` and `supabase/` are not scaffolded yet — they require the Flutter SDK and
Supabase CLI respectively, which aren't part of this repo. See "Status" below.

## Status

- ✅ **admin/** — scaffolded (Vite + React 19 + TypeScript, Tailwind v4, shadcn/ui,
  TanStack Query/Table, React Router, react-hook-form + zod, Supabase JS client).
- ⏳ **supabase/** — pending. Requires the [Supabase CLI](https://supabase.com/docs/guides/cli)
  installed locally, then `supabase init` inside `supabase/`.
- ⏳ **app/** — pending. Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
  installed locally, then `flutter create app`.

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

## Local setup — supabase / app

Not available yet. Once the Supabase CLI and Flutter SDK are installed, these
sections will be filled in with real setup steps (`supabase start`, migrations,
`flutter run`, etc.) as part of the next scaffolding pass.

## Contributing

- Schema changes only via Supabase CLI migrations — never edit tables directly
  in the dashboard.
- Every RLS policy needs a pgTAP test proving both the allowed and denied case.
- No secrets in Git. Each package keeps a `.env.example` with placeholder names;
  real values go in a gitignored `.env` / `.env.local`.

See [`CLAUDE.md`](./CLAUDE.md) for the full set of rules and the phase-by-phase
build order.
