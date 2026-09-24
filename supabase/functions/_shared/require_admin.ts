import { createClient } from 'jsr:@supabase/supabase-js@2'
import type { Database } from './database.types.ts'

/**
 * Verifies the caller is an active admin with aal2 satisfied, by forwarding their own
 * Authorization header and calling the same `is_admin()` used everywhere else (RLS
 * included) — one source of truth for "is this an admin", not a second copy of the check.
 * Returns their admins.id (needed for actor_id on audit_log entries) or null if not an
 * admin / no/invalid bearer token.
 */
export async function requireAdmin(req: Request): Promise<{ adminId: string } | null> {
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) return null

  const userClient = createClient<Database>(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: isAdmin, error: rpcError } = await userClient.rpc('is_admin')
  if (rpcError || !isAdmin) return null

  const {
    data: { user },
  } = await userClient.auth.getUser()
  if (!user) return null

  const { data: admin } = await userClient
    .from('admins')
    .select('id')
    .eq('user_id', user.id)
    .maybeSingle()
  if (!admin) return null

  return { adminId: admin.id }
}
