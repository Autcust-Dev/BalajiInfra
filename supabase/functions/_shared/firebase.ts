// Verifies a raw Firebase ID token without the Firebase Admin SDK (not Deno-edge-friendly).
// Signature is checked against Google's public JWKS for Firebase ID tokens; issuer/audience
// are checked against this project's Firebase project id (CLAUDE.md §4 rule 13/14 — the
// same "standard raw-Firebase-ID-token shape" that public.is_tenant() checks at the RLS
// layer, so both layers agree on what a valid tenant token looks like).
//
// NOTE(Phase 3): verify this against current Firebase/Supabase docs before relying on it in
// production (CLAUDE.md §4 rule 14) — this endpoint and claim shape are Google's documented
// ID token verification approach as of this writing, but Firebase APIs change.
import { createRemoteJWKSet, decodeJwt, errors as joseErrors, jwtVerify } from 'npm:jose@5'

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
)

export interface VerifiedFirebaseToken {
  uid: string
  phoneNumber: string
}

// Local/dev-only diagnostic logging (CLAUDE.md §4 rule 22: never log personal data — this
// only ever logs project ids and error metadata, never the token, sub, or phone_number).
// Gated on an env var so it can never accidentally turn on hosted: hosted secrets are set
// via `supabase secrets set` (rule 12), never a committed file, so LOCAL_DEBUG_FIREBASE_AUTH
// is unset (falsy) there by construction. Enable locally via supabase/functions/.env (see
// supabase/functions/.env.example) — supabase start / functions serve auto-load that file.
const DEBUG_AUTH = Deno.env.get('LOCAL_DEBUG_FIREBASE_AUTH') === 'true'

function logVerificationFailure(idToken: string, projectId: string, err: unknown): void {
  let tokenIssuer = '<unparseable>'
  let tokenAudience = '<unparseable>'
  try {
    // decodeJwt reads the payload without checking the signature — fine for diagnostics,
    // this is never treated as a verified/trusted claim.
    const unverified = decodeJwt(idToken)
    tokenIssuer = typeof unverified.iss === 'string' ? unverified.iss : '<missing>'
    tokenAudience = typeof unverified.aud === 'string' ? unverified.aud : '<missing>'
  } catch {
    // Not even a well-formed JWT — leave the placeholders above.
  }

  let errorDetail = err instanceof Error ? `${err.name}: ${err.message}` : String(err)
  if (err instanceof joseErrors.JOSEError) {
    errorDetail = `${err.name} (code=${err.code}): ${err.message}`
    if (err instanceof joseErrors.JWTClaimValidationFailed) {
      errorDetail += ` [claim=${err.claim}, reason=${err.reason}]`
    }
  } else {
    // jwtVerify's JWKS fetch failures (network/DNS/timeout reaching Google from inside the
    // edge-runtime container) throw plain errors that don't extend JOSEError — call that
    // out explicitly since it looks identical to a claim mismatch from the HTTP response.
    errorDetail += ' (does not extend JOSEError — likely a JWKS fetch/network failure, not a signature or claim mismatch)'
  }

  console.error(
    '[link-firebase-uid][LOCAL_DEBUG] Firebase ID token verification failed:',
    JSON.stringify(
      {
        expectedProjectId: projectId,
        expectedIssuer: `https://securetoken.google.com/${projectId}`,
        tokenIssuer,
        tokenAudience,
        error: errorDetail,
      },
      null,
      2,
    ),
  )
}

export async function verifyFirebaseIdToken(
  idToken: string,
  projectId: string,
): Promise<VerifiedFirebaseToken> {
  let result: Awaited<ReturnType<typeof jwtVerify>>
  try {
    result = await jwtVerify(idToken, FIREBASE_JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    })
  } catch (err) {
    if (DEBUG_AUTH) logVerificationFailure(idToken, projectId, err)
    throw err
  }

  const { payload } = result
  const uid = payload.sub
  const phoneNumber = payload.phone_number

  if (typeof uid !== 'string' || typeof phoneNumber !== 'string') {
    throw new Error('Firebase ID token is missing sub or phone_number claim')
  }

  return { uid, phoneNumber }
}
