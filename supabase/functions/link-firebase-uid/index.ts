// Called right after Firebase phone sign-in completes (Phase 3 first-login flow). Links
// the newly-authenticated Firebase UID onto the matching tenants row — this has to run as
// service_role (see the "Trusted backend role" comment on tenants.firebase_uid in
// supabase/migrations/20260918200112_tenants.sql): until firebase_uid is set,
// public.is_tenant() is false for this session, so the tenant can't write their own row via
// RLS yet. Not a Supabase-issued session, so verify_jwt is off (supabase/config.toml) and
// the Firebase ID token is verified here instead — see _shared/firebase.ts.
import { createServiceRoleClient } from '../_shared/service_role_client.ts'
import { verifyFirebaseIdToken } from '../_shared/firebase.ts'

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method not allowed' }, 405)
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice('Bearer '.length) : null
  if (!idToken) {
    return jsonResponse({ error: 'missing bearer token' }, 401)
  }

  const supabase = createServiceRoleClient()

  const { data: config } = await supabase
    .from('app_config')
    .select('value')
    .eq('key', 'firebase_project_id')
    .maybeSingle()
  const projectId = config?.value
  if (typeof projectId !== 'string') {
    // Fail-closed: unset locally until seed.sql runs, unset on hosted until the human sets
    // it once via the Studio SQL editor (CLAUDE.md §4 rule 13).
    return jsonResponse({ error: 'firebase project id not configured' }, 500)
  }

  let verified
  try {
    verified = await verifyFirebaseIdToken(idToken, projectId)
  } catch {
    return jsonResponse({ error: 'invalid firebase id token' }, 401)
  }

  const { data: tenant } = await supabase
    .from('tenants')
    .select('id, firebase_uid')
    .eq('phone', verified.phoneNumber)
    .maybeSingle()

  if (!tenant) {
    // Should be rare — check-phone already gated OTP send on a matching tenant existing.
    // Could still happen if an admin deletes the tenant mid-flow.
    return jsonResponse({ error: 'no matching tenant' }, 404)
  }

  if (tenant.firebase_uid !== null && tenant.firebase_uid !== verified.uid) {
    // Same phone number, different Firebase UID than what's already linked — don't silently
    // relink; surface it rather than letting one phone's session hijack another's tenant row.
    return jsonResponse({ error: 'unable to link' }, 409)
  }

  if (tenant.firebase_uid === null) {
    const { error } = await supabase
      .from('tenants')
      .update({ firebase_uid: verified.uid })
      .eq('id', tenant.id)
    if (error) {
      return jsonResponse({ error: 'failed to link tenant' }, 500)
    }
  }

  return jsonResponse({ linked: true })
})
