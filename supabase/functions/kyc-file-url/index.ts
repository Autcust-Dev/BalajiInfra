// Issues a short-lived signed URL for an admin to view or download a KYC document
// (CLAUDE.md §4 rule 20: signed URLs valid <= 60 seconds, no public URLs ever) and logs the
// access to audit_log — view and download are logged as distinct actions, not one merged
// "accessed" event, per the client's requirement.
import { createServiceRoleClient } from '../_shared/service_role_client.ts'
import { requireAdmin } from '../_shared/require_admin.ts'

const SIGNED_URL_TTL_SECONDS = 60

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

  const admin = await requireAdmin(req)
  if (!admin) {
    return jsonResponse({ error: 'unauthorized' }, 403)
  }

  let body: unknown
  try {
    body = await req.json()
  } catch {
    return jsonResponse({ error: 'invalid body' }, 400)
  }

  const { submission_id, file, action } = body as Record<string, unknown>
  if (
    typeof submission_id !== 'string' ||
    (file !== 'aadhaar' && file !== 'selfie') ||
    (action !== 'view' && action !== 'download')
  ) {
    return jsonResponse({ error: 'submission_id, file (aadhaar|selfie), action (view|download) required' }, 400)
  }

  const supabase = createServiceRoleClient()

  const { data: submission } = await supabase
    .from('kyc_submissions')
    .select('tenant_id, aadhaar_path, selfie_path')
    .eq('id', submission_id)
    .maybeSingle()

  if (!submission) {
    return jsonResponse({ error: 'not found' }, 404)
  }

  const path = file === 'aadhaar' ? submission.aadhaar_path : submission.selfie_path

  const { data: signed, error: signError } = await supabase.storage
    .from('kyc')
    .createSignedUrl(path, SIGNED_URL_TTL_SECONDS, action === 'download' ? { download: true } : undefined)

  if (signError || !signed) {
    return jsonResponse({ error: 'failed to sign url' }, 500)
  }

  await supabase.from('audit_log').insert({
    actor_type: 'admin',
    actor_id: admin.adminId,
    action: action === 'download' ? 'download_document' : 'view_document',
    table_name: 'kyc_submissions',
    row_id: submission_id,
    after: { file, tenant_id: submission.tenant_id },
  })

  return jsonResponse({ url: signed.signedUrl, expires_in: SIGNED_URL_TTL_SECONDS })
})
