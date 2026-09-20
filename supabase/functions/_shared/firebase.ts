// Verifies a raw Firebase ID token without the Firebase Admin SDK (not Deno-edge-friendly).
// Signature is checked against Google's public JWKS for Firebase ID tokens; issuer/audience
// are checked against this project's Firebase project id (CLAUDE.md §4 rule 13/14 — the
// same "standard raw-Firebase-ID-token shape" that public.is_tenant() checks at the RLS
// layer, so both layers agree on what a valid tenant token looks like).
//
// NOTE(Phase 3): verify this against current Firebase/Supabase docs before relying on it in
// production (CLAUDE.md §4 rule 14) — this endpoint and claim shape are Google's documented
// ID token verification approach as of this writing, but Firebase APIs change.
import { createRemoteJWKSet, jwtVerify } from 'npm:jose@5'

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
)

export interface VerifiedFirebaseToken {
  uid: string
  phoneNumber: string
}

export async function verifyFirebaseIdToken(
  idToken: string,
  projectId: string,
): Promise<VerifiedFirebaseToken> {
  const { payload } = await jwtVerify(idToken, FIREBASE_JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  })

  const uid = payload.sub
  const phoneNumber = payload.phone_number

  if (typeof uid !== 'string' || typeof phoneNumber !== 'string') {
    throw new Error('Firebase ID token is missing sub or phone_number claim')
  }

  return { uid, phoneNumber }
}
