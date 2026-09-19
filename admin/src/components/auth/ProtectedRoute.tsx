import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '@/lib/auth-context'

/**
 * Route guard order (CLAUDE.md §4 rule 28, admin side): no session -> /login; session but
 * aal1 only and no factor -> /mfa/enroll; session, factor exists, aal1 -> /mfa/verify;
 * aal2 -> render the app. This is a UX convenience only — RLS is what actually enforces
 * access on every table regardless of what the UI shows or hides.
 */
export function ProtectedRoute() {
  const { status } = useAuth()
  const location = useLocation()

  if (status === 'loading') return null

  if (status === 'signed-out') {
    return <Navigate to="/login" state={{ from: location }} replace />
  }
  if (status === 'mfa-enroll') {
    return <Navigate to="/mfa/enroll" replace />
  }
  if (status === 'mfa-verify') {
    return <Navigate to="/mfa/verify" replace />
  }

  return <Outlet />
}
