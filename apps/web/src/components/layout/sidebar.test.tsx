import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { renderApp } from '../../test/render-app'

const signedIn = {
  'GET /api/companies/1/session': { body: { success: true, message: '', data: { id: 1, name: 'Ada', email: 'a@factorial.test', roles: [] } } },
  'GET /api/companies/1/people': { body: { success: true, message: '', data: [] } },
  'GET /api/companies/1/departments': { body: { success: true, message: '', data: [] } },
}

describe('Sidebar', () => {
  it('renders a link for every top-level page, plus Settings', async () => {
    mockApi(signedIn)
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
    expect(screen.getByRole('link', { name: 'Settings' })).toBeInTheDocument()
  })

  it('marks the current route as active and no other route', async () => {
    mockApi(signedIn)
    await renderApp('/graph')

    expect(screen.getByRole('link', { name: 'Graph' })).toHaveAttribute('data-active', 'true')
    expect(screen.getByRole('link', { name: 'Assemble' })).toHaveAttribute('data-active', 'false')
  })
})
