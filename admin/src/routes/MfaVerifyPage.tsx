import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { InputOTP, InputOTPGroup, InputOTPSlot } from '@/components/ui/input-otp'
import { useAuth } from '@/lib/auth-context'
import { supabase } from '@/lib/supabase'

/** Returning-session MFA challenge — a factor is already enrolled, this session just
 * hasn't cleared aal2 yet. */
export function MfaVerifyPage() {
  const { refreshAal, signOut } = useAuth()
  const [factorId, setFactorId] = useState<string | null>(null)
  const [challengeId, setChallengeId] = useState<string | null>(null)
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    async function startChallenge() {
      const { data: factors, error: factorsError } = await supabase.auth.mfa.listFactors()
      if (factorsError) {
        setError(factorsError.message)
        return
      }
      const factor = factors.totp[0]
      if (!factor) {
        setError('No MFA factor found on this account.')
        return
      }
      setFactorId(factor.id)

      const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({
        factorId: factor.id,
      })
      if (challengeError) {
        setError(challengeError.message)
        return
      }
      setChallengeId(challenge.id)
    }
    void startChallenge()
  }, [])

  async function verifyCode() {
    if (!factorId || !challengeId) return
    setSubmitting(true)
    setError(null)
    const { error: verifyError } = await supabase.auth.mfa.verify({
      factorId,
      challengeId,
      code,
    })
    setSubmitting(false)
    if (verifyError) {
      setError(verifyError.message)
      return
    }
    await refreshAal()
  }

  return (
    <div className="flex min-h-svh items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-4 text-center">
        <h1 className="text-foreground text-2xl font-medium">Enter your 2FA code</h1>
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
          onClick={verifyCode}
          disabled={code.length !== 6 || submitting || !challengeId}
          className="w-full"
        >
          {submitting ? 'Verifying…' : 'Verify'}
        </Button>
        <Button variant="ghost" className="w-full" onClick={() => void signOut()}>
          Sign out
        </Button>
      </div>
    </div>
  )
}
