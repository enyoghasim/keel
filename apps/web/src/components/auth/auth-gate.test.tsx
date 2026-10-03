import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Person } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { mockApi, workspaceWithoutCompany } from '../../test/mock-api'
import { renderApp } from '../../test/render-app'

const ada: Person = {
  id: 1,
  name: 'Ada Nwosu',
  email: 'ada@factorial.test',
  title: 'HR Admin',
  department_id: null,
  manager_id: null,
  location: null,
  start_date: null,
  roles: ['hr_admin'],
}

const unauthorized = { status: 401, body: { success: false, message: 'Not signed in.' } }

describe('AuthGate', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows a login form instead of the page when no one is signed in', async () => {
    mockApi({ 'GET /api/companies/1/session': unauthorized })

    await renderApp('/graph')

    expect(await screen.findByRole('heading', { name: 'Sign in to Keel' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Graph' })).not.toBeInTheDocument()
  })

  it('renders the page once sign-in succeeds', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/session': unauthorized,
      'POST /api/companies/1/session': { body: { success: true, message: 'Signed in.', data: ada } },
      'GET /api/companies/1/people': { body: { success: true, message: '', data: [] } },
      'GET /api/companies/1/departments': { body: { success: true, message: '', data: [] } },
    })

    await renderApp('/graph')
    await screen.findByRole('heading', { name: 'Sign in to Keel' })

    await user.type(screen.getByLabelText('Email'), 'ada@factorial.test')
    await user.type(screen.getByLabelText('Password'), 'password')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('heading', { name: 'Graph' })).toBeInTheDocument()
  })

  it('shows the error from a failed sign-in attempt', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/session': unauthorized,
      'POST /api/companies/1/session': { status: 401, body: { success: false, message: 'Incorrect email or password.' } },
    })

    await renderApp('/graph')
    await screen.findByRole('heading', { name: 'Sign in to Keel' })

    await user.type(screen.getByLabelText('Email'), 'ada@factorial.test')
    await user.type(screen.getByLabelText('Password'), 'wrong')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByText('Incorrect email or password.')).toBeInTheDocument()
  })

  it('lets /assemble through without a sign-in only while the company is still assembling', async () => {
    mockApi({
      'GET /api/workspace': { body: { success: true, message: '', data: { company: { id: 1, name: 'Factorial', assembling: true } } } },
    })

    await renderApp('/assemble')

    expect(await screen.findByRole('heading', { name: 'Assemble' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Sign in to Keel' })).not.toBeInTheDocument()
  })

  it('asks for a sign-in on /assemble once the company is set up', async () => {
    mockApi({ 'GET /api/companies/1/session': unauthorized })

    await renderApp('/assemble')

    expect(await screen.findByRole('heading', { name: 'Sign in to Keel' })).toBeInTheDocument()
  })

  it('sends any page to /assemble while the backend has no company, with no sign-in', async () => {
    mockApi({ 'GET /api/workspace': workspaceWithoutCompany })

    const { router } = await renderApp('/graph')

    expect(await screen.findByRole('heading', { name: 'Assemble' })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe('/assemble')
  })

  it('says so when the server cannot be reached, rather than showing a blank page', async () => {
    mockApi({ 'GET /api/workspace': { status: 500, body: { success: false, message: 'boom' } } })

    await renderApp('/graph')

    expect(await screen.findByText(/can't reach its server/)).toBeInTheDocument()
  })
})
