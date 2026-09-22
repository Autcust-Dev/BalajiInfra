export type CustomClaims = Record<string, unknown>;

/**
 * Merges `role: "authenticated"` into whatever custom claims a user already has, touching
 * nothing else. Supabase's third-party Firebase auth integration reads this claim to decide
 * which Postgres role a request runs as — without it, the session stays `anon`, and every
 * tenant-facing table (tenants, consents, kyc_submissions, dues, payments) is GRANTed only
 * to `authenticated` (CLAUDE.md §4 rule 14), so the request gets no tenant data at all,
 * independent of RLS. See supabase/tests/013_anon_role_blocked_without_authenticated_claim.sql
 * for the pgTAP proof of that failure mode.
 *
 * Pulled out of index.ts so it's testable without pulling in firebase-functions' types.
 */
export function computeClaimsWithAuthenticatedRole(
  existingClaims: CustomClaims | undefined,
): CustomClaims {
  return { ...(existingClaims ?? {}), role: "authenticated" };
}
