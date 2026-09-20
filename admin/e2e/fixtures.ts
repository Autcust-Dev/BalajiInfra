import type { Page } from '@playwright/test'
import { Secret, TOTP } from 'otpauth'

// Seeded local-only accounts (supabase/seed.sql) — never real credentials.
export const OWNER = { email: 'owner@example.test', password: 'local-dev-only' }
export const STAFF = { email: 'staff@example.test', password: 'local-dev-only' }

// Persists across calls within a single worker process: the suite runs serially
// (playwright.config.ts: workers: 1), so once a user's MFA factor is enrolled by an
// earlier test, later logins for the same user reuse the same captured secret to compute
// a fresh TOTP code, rather than re-enrolling (an account can only enroll once).
const totpSecrets = new Map<string, string>()

/**
 * Logs in as the given seeded admin, handling both first-ever login (enrolls a TOTP
 * factor, verifying it once to complete enrollment) and a returning login (challenges the
 * already-known factor) — ends on /properties either way.
 */
export async function loginAs(
  page: Page,
  { email, password }: { email: string; password: string },
) {
  let capturedSecret: string | null = null
  const onResponse = async (res: import('@playwright/test').Response) => {
    if (res.request().method() === 'POST' && res.url().includes('/factors')) {
      try {
        const body = await res.json()
        if (body?.totp?.secret) capturedSecret = body.totp.secret
      } catch {
        // not a JSON body we care about
      }
    }
  }
  page.on('response', onResponse)

  await page.goto('/login')
  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Password').fill(password)
  await page.getByRole('button', { name: 'Sign in' }).click()

  await Promise.race([
    page.waitForURL('**/mfa/enroll', { timeout: 10_000 }),
    page.waitForURL('**/mfa/verify', { timeout: 10_000 }),
  ])

  let secret = totpSecrets.get(email)

  if (page.url().includes('/mfa/enroll')) {
    await page.getByRole('button', { name: 'Start setup' }).click()
    await page.waitForTimeout(300) // let the enroll response resolve
    if (!capturedSecret) throw new Error(`Could not capture a TOTP secret for ${email}`)
    secret = capturedSecret
    totpSecrets.set(email, secret)
  }

  page.off('response', onResponse)

  if (!secret) {
    throw new Error(
      `No TOTP secret known for ${email} but the session needs /mfa/verify — ` +
        'this usually means the local DB already has a factor enrolled from a previous ' +
        'run outside this test process. Run `supabase db reset` before re-running e2e locally.',
    )
  }

  const code = new TOTP({ secret: Secret.fromBase32(secret), digits: 6, period: 30 }).generate()
  const otpInputs = page.locator('input[inputmode="numeric"], input[maxlength="1"]')
  const count = await otpInputs.count()
  if (count === 6) {
    for (let i = 0; i < 6; i++) await otpInputs.nth(i).fill(code[i])
  } else {
    // shadcn's InputOTP may render as a single underlying input rather than 6 visual slots.
    await page.locator('input').last().fill(code)
  }

  await page.getByRole('button', { name: /^Verify/ }).click()
  await page.waitForURL('**/properties', { timeout: 10_000 })
}
