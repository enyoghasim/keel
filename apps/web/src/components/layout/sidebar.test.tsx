import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { renderApp } from '../../test/render-app'

describe('Sidebar', () => {
  it('renders a link for every top-level page, plus Settings', async () => {
    await renderApp('/assemble')

    const expectedLabels = [
      'Assemble',
      'Graph',
      'Policies',
      'Workflows',
      'Proposals',
      'Inbox',
      'Insights',
      'Trust',
    ]
    for (const label of expectedLabels) {
      expect(screen.getByRole('link', { name: label })).toBeInTheDocument()
    }
    expect(screen.getByRole('button', { name: 'Settings' })).toBeInTheDocument()
  })

  it('marks the current route as active and no other route', async () => {
    await renderApp('/graph')

    expect(screen.getByRole('link', { name: 'Graph' }).className).toMatch(/bg-sidebar-accent/)
    expect(screen.getByRole('link', { name: 'Assemble' }).className).not.toMatch(/bg-sidebar-accent/)
  })
})
