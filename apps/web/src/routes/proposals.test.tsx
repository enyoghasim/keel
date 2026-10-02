import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ChangeProposal, Department, Person } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { setCurrentCompanyId } from '../lib/current-company'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

const people: Person[] = [
  {
    id: 1,
    name: 'Tunde Bakare',
    email: 'tunde@nubo.test',
    title: 'Sales Manager',
    department_id: 10,
    manager_id: null,
    location: null,
    start_date: null,
    roles: [],
  },
  {
    id: 2,
    name: 'Ada Nwosu',
    email: 'ada@nubo.test',
    title: 'Head of Operations',
    department_id: 20,
    manager_id: null,
    location: null,
    start_date: null,
    roles: [],
  },
  {
    id: 3,
    name: 'Ngozi Doe',
    email: 'ngozi@nubo.test',
    title: 'Sales Rep',
    department_id: 10,
    manager_id: 1,
    location: null,
    start_date: null,
    roles: [],
  },
]

const departments: Department[] = [
  { id: 10, name: 'Sales', head_id: 1 },
  { id: 20, name: 'Operations', head_id: 2 },
]

const cleanProposal: ChangeProposal = {
  id: 1,
  company_id: 1,
  kind: 'org',
  title: 'Move Ngozi under Ada',
  diff: [{ op: 'change_manager', person_id: 3, from: 1, to: 2 }],
  impact: {
    rerouted: [
      {
        person_id: 3,
        before: { outcome: 'require_approval', rule_keys: ['default'], approvers: [1], errors: [], explanation: null },
        after: { outcome: 'require_approval', rule_keys: ['default'], approvers: [2], errors: [], explanation: null },
      },
    ],
    broken: [],
    self_approval: [],
    approval_load_changes: [],
    rerouted_in_flight: [],
  },
  proposed_by: 'agent',
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  created_at: '2026-01-01T00:00:00Z',
}

const brokenProposal: ChangeProposal = {
  id: 2,
  company_id: 1,
  kind: 'org',
  title: 'Remove Sales department head',
  diff: [{ op: 'set_department_head', department_id: 10, to: null }],
  impact: {
    rerouted: [],
    broken: [
      {
        person_id: 3,
        before: { outcome: 'require_approval', rule_keys: ['needs_head_approval'], approvers: [1], errors: [], explanation: null },
        after: { outcome: 'blocked', rule_keys: [], approvers: [], errors: ['Sales has no department head'], explanation: null },
      },
    ],
    self_approval: [],
    approval_load_changes: [],
    rerouted_in_flight: [],
  },
  proposed_by: 'user',
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  created_at: '2026-01-02T00:00:00Z',
}

const peopleRoute = { 'GET /api/companies/1/people': { body: { success: true, message: '', data: people } } }
const departmentsRoute = {
  'GET /api/companies/1/departments': { body: { success: true, message: '', data: departments } },
}

// A person distinct from `people` above, so the Topbar's signed-in chip
// doesn't add an extra occurrence of a name these tests already assert on.
const currentPerson: Person = {
  id: 99,
  name: 'Chiamaka Eze',
  email: 'chiamaka@nubo.test',
  title: 'HR Admin',
  department_id: null,
  manager_id: null,
  location: null,
  start_date: null,
  roles: ['hr_admin'],
}
const sessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: currentPerson } } }

describe('/proposals', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when no company has been selected yet', async () => {
    await renderApp('/proposals')

    expect(await screen.findByRole('heading', { name: 'Proposals' })).toBeInTheDocument()
    expect(screen.getByText(/assemble one on the assemble page first/i)).toBeInTheDocument()
  })

  it('shows an empty state when the company has no proposals', async () => {
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [] } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')

    expect(await screen.findByText(/no change proposals yet/i)).toBeInTheDocument()
  })

  it('lists proposals with their kind, status, proposer and impact counts', async () => {
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': {
        body: { success: true, message: '', data: [cleanProposal, brokenProposal] },
      },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')

    expect(await screen.findByText('Move Ngozi under Ada')).toBeInTheDocument()
    expect(screen.getByText('Remove Sales department head')).toBeInTheDocument()
    expect(screen.getByText(/keel agent/i)).toBeInTheDocument()
    expect(screen.getAllByText(/1 rerouted/)).toHaveLength(1)
    expect(screen.getAllByText(/1 broken/)).toHaveLength(1)
  })

  it('expands a row to show the diff in plain language with names resolved, not raw ids', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [cleanProposal] } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))

    expect(await screen.findByText('Ngozi Doe now reports to Ada Nwosu instead of Tunde Bakare')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Approve' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Reject' })).toBeInTheDocument()
  })

  it('disables Approve while there are broken chains, until Approve anyway is ticked with a reason', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [brokenProposal] } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Remove Sales department head/ }))

    const approveButton = await screen.findByRole('button', { name: 'Approve' })
    expect(approveButton).toBeDisabled()

    await user.click(screen.getByRole('checkbox'))
    expect(approveButton).toBeDisabled()

    await user.type(
      await screen.findByLabelText('Reason for approving anyway'),
      'Sales is folding into Ops next week',
    )
    expect(approveButton).toBeEnabled()
  })

  it('approves a clean proposal and refreshes the list to show it decided', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const approved = { ...cleanProposal, status: 'approved' as const, decided_at: '2026-01-03T00:00:00Z' }
    mockApi({
      'GET /api/companies/1/change_proposals': [
        { body: { success: true, message: '', data: [cleanProposal] } },
        { body: { success: true, message: '', data: [approved] } },
      ],
      'POST /api/companies/1/change_proposals/1/approve': {
        body: { success: true, message: 'Change proposal approved.', data: approved },
      },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))
    await user.click(await screen.findByRole('button', { name: 'Approve' }))

    expect(await screen.findByText(/this proposal was approved/i)).toBeInTheDocument()
  })

  it('rejects a proposal and refreshes the list to show it decided', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const rejected = { ...cleanProposal, status: 'rejected' as const, decided_at: '2026-01-03T00:00:00Z' }
    mockApi({
      'GET /api/companies/1/change_proposals': [
        { body: { success: true, message: '', data: [cleanProposal] } },
        { body: { success: true, message: '', data: [rejected] } },
      ],
      'POST /api/companies/1/change_proposals/1/reject': {
        body: { success: true, message: 'Change proposal rejected.', data: rejected },
      },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))
    await user.click(await screen.findByRole('button', { name: 'Reject' }))

    expect(await screen.findByText(/this proposal was rejected/i)).toBeInTheDocument()
  })
})
