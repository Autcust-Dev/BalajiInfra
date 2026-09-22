# Firebase Cloud Functions

Currently one function: `beforeSignIn`, a 2nd-gen Auth blocking function
(`functions/src/index.ts`) that sets the `role: "authenticated"` custom claim on every
tenant's Firebase ID token. Supabase's third-party Firebase auth integration reads that
claim to decide which Postgres role a request runs as; without it every tenant-facing table
(`tenants`, `consents`, `kyc_submissions`, `dues`, `payments`) is `GRANT`ed only to
`authenticated`, so a token missing the claim gets no tenant data at all — see CLAUDE.md §4
rule 14 and `supabase/tests/013_anon_role_blocked_without_authenticated_claim.sql`.

It does nothing else: no other claims, no secrets, no network calls.

## Prerequisites (human-only — needs Firebase Console access)

Blocking functions require both of these, in order, before the first deploy:

1. **Blaze (pay-as-you-go) billing plan** with a budget alert (already listed in
   CLAUDE.md §8's "tasks only the human can do").
2. **Upgrade the Firebase project to Identity Platform.** In the Firebase Console:
   Authentication → Settings → "Upgrade to Identity Platform". This is required
   specifically for Auth blocking functions (2nd gen) — plain Firebase Auth cannot run
   them.

## Local setup

```sh
cd firebase/functions
npm install
npm run typecheck
npm test
```

## Deploy (human-only — do not run until the prerequisites above are done)

```sh
# from firebase/
npx firebase-tools deploy --only functions:beforeSignIn --project balajiinfraandhostel
```

(or `npm run deploy` from `firebase/functions/`, which runs the same command via the
`firebase` CLI if installed globally).

Firebase allows only one `beforeSignIn`/`beforeUserSignedIn` function per project, so this
is safe to redeploy in place — it always replaces the same function.

## Verifying it worked

After deploying and signing a test user in via the app's OTP flow, decode their Firebase ID
token (e.g. paste it into jwt.io) and confirm the payload has `"role": "authenticated"`. If
it's missing, `link-firebase-uid` and every tenant RLS-gated query will fail — see the
pgTAP test referenced above for what that failure looks like at the database layer.
