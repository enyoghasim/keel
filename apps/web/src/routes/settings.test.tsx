import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { mockApi, workspaceWithCompany } from '../test/mock-api'
import { renderApp } from '../test/render-app'

vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: vi.fn(() => ({ unsubscribe: vi.fn() })) } })),
}))

const me = { id: 1, name: 'Ifeoma Adeyemi', email: 'i@nubo.test', title: 'Head of People', department_id: null, manager_id: null, location: null, start_date: null, roles: [] }

describe('/settings', () => {
  beforeEach(() => localStorage.clear())

  it('shows the person’s MCP tokens, and the sidebar Settings link leads here', async () => {
    const user = userEvent.setup()
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

  describe('Reset demo', () => {
    const routes = {
      'GET /api/companies/1/personal_access_tokens': { body: { success: true, message: '', data: [] } },
      'GET /api/companies/1/mcp_calls': { body: { success: true, message: '', data: [] } },
    }
    const resettable = { body: { success: true, message: '', data: { company: { id: 1, name: 'Nubo', assembling: false }, demo_reset: true } } }
    const hr = { body: { success: true, message: '', data: { ...me, roles: ['hr_admin'] } } }

    it('is offered to an hr_admin on a deployment that turned it on', async () => {
      mockApi({ ...routes, 'GET /api/workspace': resettable, 'GET /api/companies/1/session': hr })
      await renderApp('/settings')

      expect(await screen.findByRole('region', { name: 'Reset demo' })).toBeInTheDocument()
    })

    it('is not offered on a deployment that has not turned it on', async () => {
      mockApi({ ...routes, 'GET /api/workspace': workspaceWithCompany, 'GET /api/companies/1/session': hr })
      await renderApp('/settings')

      await screen.findByRole('region', { name: 'Personal access tokens' })
      expect(screen.queryByRole('region', { name: 'Reset demo' })).not.toBeInTheDocument()
    })

    it('is not offered to someone who is not an hr_admin', async () => {
      mockApi({ ...routes, 'GET /api/workspace': resettable, 'GET /api/companies/1/session': { body: { success: true, message: '', data: me } } })
      await renderApp('/settings')

      await screen.findByRole('region', { name: 'Personal access tokens' })
      expect(screen.queryByRole('region', { name: 'Reset demo' })).not.toBeInTheDocument()
    })
  })
})
