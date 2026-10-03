import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { mockApi, workspaceWithoutCompany } from '../test/mock-api'
import { renderApp } from '../test/render-app'

describe('/ route', () => {
  it('sends a fresh browser to Assemble while the backend has no company', async () => {
    mockApi({ 'GET /api/workspace': workspaceWithoutCompany })
    const { router } = await renderApp('/')

    expect(await screen.findByRole('heading', { name: 'Assemble' })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe('/assemble')
  })

  it('sends a fresh browser to sign-in, then the graph, once the backend has a company', async () => {
    const user = userEvent.setup()
    const ada = { id: 1, name: 'Ada Nwosu', email: 'ada@factorial.test', roles: ['hr_admin'] }
    mockApi({
      'GET /api/companies/1/session': { status: 401, body: { success: false, message: 'Not signed in.' } },
      'POST /api/companies/1/session': { body: { success: true, message: 'Signed in.', data: ada } },
      'GET /api/companies/1/people': { body: { success: true, message: '', data: [] } },
      'GET /api/companies/1/departments': { body: { success: true, message: '', data: [] } },
    })
    const { router } = await renderApp('/')

    await user.type(await screen.findByLabelText('Email'), 'ada@factorial.test')
    await user.type(screen.getByLabelText('Password'), 'password')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('heading', { name: 'Graph' })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe('/graph')
  })
})
