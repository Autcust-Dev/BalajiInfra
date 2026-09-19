import { render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import { StatusGate } from './StatusGate'

const { mockUseAuth } = vi.hoisted(() => ({ mockUseAuth: vi.fn() }))
vi.mock('@/lib/auth-context', () => ({ useAuth: mockUseAuth }))

function renderLoginRoute() {
  return render(
    <MemoryRouter initialEntries={['/login']}>
      <Routes>
        <Route path="/" element={<div>protected app entry</div>} />
        <Route
          path="/login"
          element={
            <StatusGate when="signed-out">
              <div>login page</div>
            </StatusGate>
          }
        />
      </Routes>
    </MemoryRouter>,
  )
}

describe('StatusGate', () => {
  it('renders nothing while status is loading', () => {
    mockUseAuth.mockReturnValue({ status: 'loading' })
    const { container } = renderLoginRoute()
    expect(container).toBeEmptyDOMElement()
  })

  it('renders children when status matches', () => {
    mockUseAuth.mockReturnValue({ status: 'signed-out' })
    renderLoginRoute()
    expect(screen.getByText('login page')).toBeInTheDocument()
  })

  it('redirects to / when status no longer matches (e.g. login succeeded)', () => {
    mockUseAuth.mockReturnValue({ status: 'mfa-enroll' })
    renderLoginRoute()
    expect(screen.getByText('protected app entry')).toBeInTheDocument()
  })
})
