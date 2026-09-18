import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import App from './App'

describe('App', () => {
  it('renders the admin panel heading', () => {
    render(<App />)
    expect(screen.getByText('BalajiInfra Admin')).toBeInTheDocument()
  })
})
