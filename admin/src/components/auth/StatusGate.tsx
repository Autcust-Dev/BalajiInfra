import { Navigate } from 'react-router-dom'
import { useAuth, type AuthStatus } from '@/lib/auth-context'

/**
 * Guards a public/transitional route (login, mfa/enroll, mfa/verify): renders its children
 * only while `status` matches `when`, otherwise redirects to `/`. That route is wrapped in
 * ProtectedRoute, which already knows the correct destination for every other status — so
 * this never needs its own copy of the status -> route mapping. E.g. mid-MFA-enrollment,
 * visiting /login sends you to `/`, and ProtectedRoute immediately sends you on to
 * /mfa/enroll; once aal2 is satisfied, `/` just renders the app.
 */
export function StatusGate({ when, children }: { when: AuthStatus; children: React.ReactNode }) {
  const { status } = useAuth()

  if (status === 'loading') return null
  if (status !== when) return <Navigate to="/" replace />
  return children
}
