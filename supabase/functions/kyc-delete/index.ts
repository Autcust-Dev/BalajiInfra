// Deletes a KYC submission (any status — the client explicitly wants this available even
// for an approved submission, to force a resubmission) — always an individual action, no
// bulk delete. Removes the storage files and the row; tenants.kyc_status resets to
// 'not_started' automatically via the DB trigger (sync_tenant_kyc_status, extended in
// 20260924130601_kyc_submissions_delete.sql to also fire on delete), not duplicated here.
import { createServiceRoleClient } from '../_shared/service_role_client.ts'
import { requireAdmin } from '../_shared/require_admin.ts'

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

  const { submission_id } = body as Record<string, unknown>
  if (typeof submission_id !== 'string') {
    return jsonResponse({ error: 'submission_id required' }, 400)
  }

  const supabase = createServiceRoleClient()

  const { data: submission } = await supabase
    .from('kyc_submissions')
    .select('tenant_id, aadhaar_path, selfie_path, status')
    .eq('id', submission_id)
    .maybeSingle()

  if (!submission) {
    return jsonResponse({ error: 'not found' }, 404)
  }

  const { error: storageError } = await supabase.storage
    .from('kyc')
    .remove([submission.aadhaar_path, submission.selfie_path])
  if (storageError) {
    // Don't silently proceed to delete the row if the files might still be sitting in
    // storage — better to surface the failure than leave orphaned files with no submission
    // row pointing at them (they'd be effectively unreachable/unauditable afterwards).
    return jsonResponse({ error: 'failed to delete files' }, 500)
  }

  const { error: deleteError } = await supabase
    .from('kyc_submissions')
    .delete()
    .eq('id', submission_id)
  if (deleteError) {
    return jsonResponse({ error: 'failed to delete submission' }, 500)
  }

  await supabase.from('audit_log').insert({
    actor_type: 'admin',
    actor_id: admin.adminId,
    action: 'delete_submission',
    table_name: 'kyc_submissions',
    row_id: submission_id,
    before: { tenant_id: submission.tenant_id, status: submission.status },
  })

  return jsonResponse({ deleted: true })
})
