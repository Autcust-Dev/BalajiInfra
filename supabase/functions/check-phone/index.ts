// Called before sending an OTP (CLAUDE.md §4 rule 31). Response is only { allowed: boolean }
// — never reveals whether the phone exists, or whether the request was rate-limited, so a
// caller can't distinguish "not a tenant" from "you're rate-limited" from each other.
import { createServiceRoleClient } from '../_shared/service_role_client.ts'

const PHONE_E164 = /^\+91[0-9]{10}$/
const RATE_LIMIT_WINDOW_MINUTES = 15
const MAX_ATTEMPTS_PER_PHONE = 5
const MAX_ATTEMPTS_PER_IP = 20

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return jsonResponse({ allowed: false }, 405)
  }

  let phone: unknown
  try {
    ({ phone } = await req.json())
  } catch {
    return jsonResponse({ allowed: false }, 400)
  }

  if (typeof phone !== 'string' || !PHONE_E164.test(phone)) {
    return jsonResponse({ allowed: false }, 400)
  }

  const ip = req.headers.get('x-forwarded-for')?.split(',')[0].trim() ?? '0.0.0.0'
  const supabase = createServiceRoleClient()
  const windowStart = new Date(
    Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60 * 1000,
  ).toISOString()

  // Sweep this phone/ip's own expired attempts rather than running a cron job — cheap at
  // this scale, and keeps the table from growing unbounded without adding pg_cron infra.
  await supabase
    .from('phone_check_attempts')
    .delete()
    .lt('created_at', windowStart)
    .or(`phone.eq.${phone},ip.eq.${ip}`)

  const [{ count: phoneCount }, { count: ipCount }] = await Promise.all([
    supabase
      .from('phone_check_attempts')
      .select('*', { count: 'exact', head: true })
      .eq('phone', phone)
      .gte('created_at', windowStart),
    supabase
      .from('phone_check_attempts')
      .select('*', { count: 'exact', head: true })
      .eq('ip', ip)
      .gte('created_at', windowStart),
  ])

  await supabase.from('phone_check_attempts').insert({ phone, ip })

  if ((phoneCount ?? 0) >= MAX_ATTEMPTS_PER_PHONE || (ipCount ?? 0) >= MAX_ATTEMPTS_PER_IP) {
    return jsonResponse({ allowed: false })
  }

  const { data: tenant } = await supabase
    .from('tenants')
    .select('id')
    .eq('phone', phone)
    .neq('status', 'moved_out')
    .maybeSingle()

  return jsonResponse({ allowed: tenant !== null })
})
