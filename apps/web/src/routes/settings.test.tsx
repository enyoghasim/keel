import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { setCurrentCompanyId } from '../lib/current-company'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: vi.fn(() => ({ unsubscribe: vi.fn() })) } })),
}))

const me = { id: 1, name: 'Ifeoma Adeyemi', email: 'i@nubo.test', title: 'Head of People', department_id: null, manager_id: null, location: null, start_date: null, roles: [] }

describe('/settings', () => {
  beforeEach(() => localStorage.clear())

  it('shows an empty state when no company has been selected yet', async () => {
    await renderApp('/settings')

    expect(await screen.findByRole('heading', { name: 'Settings' })).toBeInTheDocument()
    expect(screen.getByText(/assemble one on the assemble page first/i)).toBeInTheDocument()
  })

  it('shows the person’s MCP tokens, and the sidebar Settings link leads here', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/session': { body: { success: true, message: '', data: me } },
      'GET /api/companies/1/personal_access_tokens': { body: { success: true, message: '', data: [] } },
      'GET /api/companies/1/mcp_calls': { body: { success: true, message: '', data: [] } },
      'GET /api/companies/1/agent_runs': { body: { success: true, message: '', data: [] } },
      'GET /api/companies/1/insights': { body: { success: true, message: '', data: [] } },
    })
    const { router } = await renderApp('/assemble')

    await user.click(await screen.findByRole('link', { name: 'Settings' }))

    expect(router.state.location.pathname).toBe('/settings')
    expect(await screen.findByRole('region', { name: 'Personal access tokens' })).toBeInTheDocument()
    expect(screen.getByText(/no tokens yet/i)).toBeInTheDocument()
    expect(await screen.findByRole('region', { name: 'MCP calls' })).toBeInTheDocument()
  })
})
