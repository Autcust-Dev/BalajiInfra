import { createClient } from 'jsr:@supabase/supabase-js@2'
import type { Database } from './database.types.ts'

// service_role client — bypasses RLS (CLAUDE.md §4 rule 11: the service_role key never
// appears in app/ or admin/, only here, read from Supabase secrets).
export function createServiceRoleClient() {
  return createClient<Database>(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )
}
