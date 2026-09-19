import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { InputOTP, InputOTPGroup, InputOTPSlot } from '@/components/ui/input-otp'
import { useAuth } from '@/lib/auth-context'
import { supabase } from '@/lib/supabase'

/**
 * First-login MFA enrollment (CLAUDE.md §4 rule 15: MFA is required, admins are
 * manual/seeded so each admin enrolls their own TOTP factor on first login rather than
 * having one provisioned for them). A freshly enrolled factor is 'unverified' until a
 * challenge/verify round trip succeeds once — this page does both: enroll then verify.
 */
export function MfaEnrollPage() {
  const { refreshAal } = useAuth()
  const [factorId, setFactorId] = useState<string | null>(null)
  const [qrSvg, setQrSvg] = useState<string | null>(null)
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  async function startEnrollment() {
    setError(null)
    const { data, error: enrollError } = await supabase.auth.mfa.enroll({ factorType: 'totp' })
    if (enrollError) {
      setError(enrollError.message)
      return
    }
    setFactorId(data.id)
    setQrSvg(data.totp.qr_code)
  }

  async function verifyEnrollment() {
    if (!factorId) return
    setSubmitting(true)
    setError(null)
    const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({
      factorId,
    })
    if (challengeError) {
      setError(challengeError.message)
      setSubmitting(false)
      return
    }
    const { error: verifyError } = await supabase.auth.mfa.verify({
      factorId,
      challengeId: challenge.id,
      code,
    })
    setSubmitting(false)
    if (verifyError) {
      setError(verifyError.message)
      return
    }
    await refreshAal()
  }

  if (!factorId || !qrSvg) {
    return (
      <div className="flex min-h-svh items-center justify-center p-4">
        <div className="w-full max-w-sm space-y-4 text-center">
          <h1 className="text-foreground text-2xl font-medium">Set up two-factor auth</h1>
          <p className="text-muted-foreground text-sm">
            Required before you can access BalajiInfra Admin. You'll need an authenticator app
            (Google Authenticator, 1Password, etc.).
          </p>
          {error && <p className="text-destructive text-sm">{error}</p>}
          <Button onClick={startEnrollment} className="w-full">
            Start setup
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div className="flex min-h-svh items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4 text-center">
        <h1 className="text-foreground text-2xl font-medium">Scan this QR code</h1>
        <div
          className="mx-auto w-48"
          // eslint-disable-next-line -- Supabase-returned inline SVG, not user input.
          dangerouslySetInnerHTML={{ __html: qrSvg }}
        />
        <p className="text-muted-foreground text-sm">
          Then enter the 6-digit code from your authenticator app.
        </p>
        <InputOTP maxLength={6} value={code} onChange={setCode}>
          <InputOTPGroup>
            <InputOTPSlot index={0} />
            <InputOTPSlot index={1} />
            <InputOTPSlot index={2} />
            <InputOTPSlot index={3} />
            <InputOTPSlot index={4} />
            <InputOTPSlot index={5} />
          </InputOTPGroup>
        </InputOTP>
        {error && <p className="text-destructive text-sm">{error}</p>}
        <Button
          onClick={verifyEnrollment}
          disabled={code.length !== 6 || submitting}
          className="w-full"
        >
          {submitting ? 'Verifying…' : 'Verify and continue'}
        </Button>
      </div>
    </div>
  )
}
