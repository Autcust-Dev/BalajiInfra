import { render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import { ProtectedRoute } from './ProtectedRoute'

const { mockUseAuth } = vi.hoisted(() => ({ mockUseAuth: vi.fn() }))
vi.mock('@/lib/auth-context', () => ({ useAuth: mockUseAuth }))

function renderAt(initialPath: string) {
  return render(
    <MemoryRouter initialEntries={[initialPath]}>
      <Routes>
        <Route path="/login" element={<div>login page</div>} />
        <Route path="/mfa/enroll" element={<div>mfa enroll page</div>} />
        <Route path="/mfa/verify" element={<div>mfa verify page</div>} />
        <Route element={<ProtectedRoute />}>
          <Route path="/" element={<div>protected app</div>} />
        </Route>
      </Routes>
    </MemoryRouter>,
  )
}

describe('ProtectedRoute', () => {
  it('renders nothing while status is loading', () => {
    mockUseAuth.mockReturnValue({ status: 'loading' })
    const { container } = renderAt('/')
    expect(container).toBeEmptyDOMElement()
  })

  it('redirects to /login when signed out', () => {
    mockUseAuth.mockReturnValue({ status: 'signed-out' })
    renderAt('/')
    expect(screen.getByText('login page')).toBeInTheDocument()
  })

  it('redirects to /mfa/enroll when no factor is enrolled (aal1, no factor)', () => {
    mockUseAuth.mockReturnValue({ status: 'mfa-enroll' })
    renderAt('/')
    expect(screen.getByText('mfa enroll page')).toBeInTheDocument()
  })

  it('redirects to /mfa/verify when a factor exists but aal2 is not yet satisfied', () => {
    mockUseAuth.mockReturnValue({ status: 'mfa-verify' })
    renderAt('/')
    expect(screen.getByText('mfa verify page')).toBeInTheDocument()
  })

  it('renders the protected app once aal2 is satisfied', () => {
    mockUseAuth.mockReturnValue({ status: 'ready' })
    renderAt('/')
    expect(screen.getByText('protected app')).toBeInTheDocument()
  })
})
