import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it, vi } from 'vitest'
import App from './App'

const { mockUseAuth } = vi.hoisted(() => ({ mockUseAuth: vi.fn() }))
vi.mock('@/lib/auth-context', () => ({ useAuth: mockUseAuth }))

describe('App', () => {
  it('redirects a signed-out visitor to the login page', () => {
    mockUseAuth.mockReturnValue({ status: 'signed-out' })
    const queryClient = new QueryClient()
    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={['/properties']}>
          <App />
        </MemoryRouter>
      </QueryClientProvider>,
    )
    expect(screen.getByText('BalajiInfra Admin')).toBeInTheDocument()
  })
})
