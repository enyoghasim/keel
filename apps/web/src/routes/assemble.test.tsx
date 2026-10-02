import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Company } from 'api-types'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { mockApi, workspaceWithoutCompany } from '../test/mock-api'
import { renderApp } from '../test/render-app'

vi.mock('../lib/direct-upload', () => ({ uploadFile: vi.fn() }))

// cable.ts creates its ActionCable consumer once, as a module-level
// singleton, the first time any test in this file renders a route that
// uses it — later tests never call createConsumer again, so the
// subscriptions.create spy has to be a stable reference captured up front
// (via vi.hoisted) rather than read back off createConsumer's call history,
// which Vitest clears before every test (clearMocks defaults to true).
const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))

import { uploadFile } from '../lib/direct-upload'

// What GET /api/workspace says before the upload, then once the company exists and is assembling.
const workspaceThenAssembling = [
  workspaceWithoutCompany,
  { body: { success: true, message: '', data: { company: { id: 7, name: 'Nubo', assembling: true } } } },
]

const company: Company = {
  id: 7,
  name: 'Nubo',
  locale: 'en',
  assemble_completed_stages: [],
  created_at: '2026-01-01T00:00:00Z',
}

describe('/assemble', () => {
  beforeEach(() => {
    localStorage.clear()
    vi.mocked(uploadFile).mockReset()
  })

  it('shows an upload form for a roster CSV and a handbook PDF', async () => {
    mockApi({ 'GET /api/workspace': workspaceWithoutCompany })
    await renderApp('/assemble')

    expect(await screen.findByRole('heading', { name: 'Assemble' })).toBeInTheDocument()
    expect(screen.getByLabelText('Company name')).toBeInTheDocument()
    expect(screen.getByLabelText('Roster CSV')).toBeInTheDocument()
    expect(screen.getByLabelText(/Handbook PDF/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Assemble company' })).toBeDisabled()
  })

  it('uploads both files, creates the company, and switches to the live progress view', async () => {
    const user = userEvent.setup()
    vi.mocked(uploadFile).mockResolvedValueOnce('roster-signed-id').mockResolvedValueOnce('handbook-signed-id')
    const fetchMock = mockApi({
      'GET /api/workspace': workspaceThenAssembling,
      'POST /api/companies': { status: 201, body: { success: true, message: 'Company created; assembling.', data: company } },
    })

    await renderApp('/assemble')

    await user.type(screen.getByLabelText('Company name'), 'Nubo')
    await user.upload(
      screen.getByLabelText('Roster CSV'),
      new File(['name,email'], 'roster.csv', { type: 'text/csv' }),
    )
    await user.upload(
      screen.getByLabelText(/Handbook PDF/),
      new File(['%PDF-'], 'handbook.pdf', { type: 'application/pdf' }),
    )
    await user.click(screen.getByRole('button', { name: 'Assemble company' }))

    expect(await screen.findByText('CSV mapping')).toBeInTheDocument()
    // the browser learns the company from the backend, not from anything it stored
    await waitFor(() => expect(fetchMock.mock.calls.filter(([url]) => url === '/api/workspace')).toHaveLength(2))
    expect(subscriptionsCreate).toHaveBeenCalledWith(
      { channel: 'AssembleChannel', company_id: '7' },
      expect.objectContaining({ received: expect.any(Function) }),
    )
  })

  it('shows an error and stays on the form when creating the company fails', async () => {
    const user = userEvent.setup()
    vi.mocked(uploadFile).mockResolvedValueOnce('roster-signed-id')
    mockApi({
      'GET /api/workspace': workspaceWithoutCompany,
      'POST /api/companies': { status: 422, body: { success: false, message: 'roster_csv is required' } },
    })

    await renderApp('/assemble')

    await user.type(screen.getByLabelText('Company name'), 'Nubo')
    await user.upload(
      screen.getByLabelText('Roster CSV'),
      new File(['name,email'], 'roster.csv', { type: 'text/csv' }),
    )
    await user.click(screen.getByRole('button', { name: 'Assemble company' }))

    expect(await screen.findByText('roster_csv is required')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Assemble company' })).toBeInTheDocument()
  })

  it('renders live progress and a completion summary as events arrive over AssembleChannel', async () => {
    const user = userEvent.setup()
    vi.mocked(uploadFile).mockResolvedValueOnce('roster-signed-id')
    mockApi({
      'GET /api/workspace': workspaceThenAssembling,
      'POST /api/companies': { status: 201, body: { success: true, message: '', data: company } },
    })

    await renderApp('/assemble')
    await user.type(screen.getByLabelText('Company name'), 'Nubo')
    await user.upload(
      screen.getByLabelText('Roster CSV'),
      new File(['name,email'], 'roster.csv', { type: 'text/csv' }),
    )
    await user.click(screen.getByRole('button', { name: 'Assemble company' }))
    await screen.findByText('CSV mapping')

    const mixin = subscriptionsCreate.mock.calls[0][1]
    mixin.received({ stage: 'csv', event: 'mapping_complete', data: { mappings: [{ column: 'Name' }] }, progress: 0.1 })
    mixin.received({
      stage: 'graph',
      event: 'person_added',
      data: { id: 1, name: 'Ada Nwosu', manager_id: null, department: 'Ops' },
      progress: 1,
    })

    expect(await screen.findByText('Mapped 1 columns')).toBeInTheDocument()
    expect(screen.getByText('Ada Nwosu added to Ops')).toBeInTheDocument()
    expect(await screen.findByText(/1 people, 1 departments, 0 policies, 0 rules, 0 workflows/)).toBeInTheDocument()
  })

  it('has nothing to upload once the deployment already has a company, and points at the graph', async () => {
    mockApi({ 'GET /api/companies/1/session': { body: { success: true, message: '', data: { id: 1, name: 'Ifeoma', roles: ['hr_admin'] } } } })
    await renderApp('/assemble')

    expect(await screen.findByText(/Nubo is already set up/)).toBeInTheDocument()
    expect(screen.queryByLabelText('Roster CSV')).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Open the company graph' })).toBeInTheDocument()
  })
})
