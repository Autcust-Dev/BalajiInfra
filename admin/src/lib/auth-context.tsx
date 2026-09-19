import type { Session } from '@supabase/supabase-js'
import { createContext, use, useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import type { Tables } from '@/types/database.types'

type AdminProfile = Tables<'admins'>

/**
 * - 'loading': initial session check in flight.
 * - 'signed-out': no session at all.
 * - 'mfa-enroll': signed in, but this account has no MFA factor enrolled yet (first login).
 * - 'mfa-verify': signed in, a factor exists, but this session hasn't cleared the aal2
 *   challenge yet.
 * - 'ready': aal2 satisfied. This still doesn't guarantee `is_admin()` is true server-side
 *   (e.g. an inactive admin row) — RLS is the real enforcement; `adminProfile` being null
 *   here just means the UI has nothing to show.
 */
export type AuthStatus = 'loading' | 'signed-out' | 'mfa-enroll' | 'mfa-verify' | 'ready'

interface AuthContextValue {
  status: AuthStatus
  session: Session | null
  adminProfile: AdminProfile | null
  refreshAal: () => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

async function resolveMfaStatus(): Promise<'mfa-enroll' | 'mfa-verify' | 'ready'> {
  const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
  if (error) throw error
  if (data.currentLevel === 'aal2') return 'ready'
  if (data.nextLevel === 'aal2') return 'mfa-verify'
  return 'mfa-enroll'
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [status, setStatus] = useState<AuthStatus>('loading')
  const [adminProfile, setAdminProfile] = useState<AdminProfile | null>(null)

  async function syncStatus(nextSession: Session | null) {
    setSession(nextSession)
    if (!nextSession) {
      setStatus('signed-out')
      setAdminProfile(null)
      return
    }

    const mfaStatus = await resolveMfaStatus()
    setStatus(mfaStatus)

    if (mfaStatus === 'ready') {
      const { data } = await supabase
        .from('admins')
        .select('*')
        .eq('user_id', nextSession.user.id)
        .maybeSingle()
      setAdminProfile(data ?? null)
    } else {
      setAdminProfile(null)
    }
  }

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      void syncStatus(data.session)
    })

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      void syncStatus(nextSession)
    })

    return () => subscription.subscription.unsubscribe()
  }, [])

  const value: AuthContextValue = {
    status,
    session,
    adminProfile,
    refreshAal: () => syncStatus(session),
    signOut: async () => {
      await supabase.auth.signOut()
    },
  }

  return <AuthContext value={value}>{children}</AuthContext>
}

export function useAuth(): AuthContextValue {
  const ctx = use(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
