import { screen } from '@testing-library/react'
import type { Person, Request } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

const me: Person = {
  id: 98,
  name: 'Ngozi Eze',
  email: 'ngozi@factorial.test',
  title: 'Sales Rep',
  department_id: 10,
  manager_id: 1,
  location: null,
  start_date: null,
  roles: [],
}
const tunde: Person = {
  id: 1,
  name: 'Tunde Bakare',
  email: 'tunde@factorial.test',
  title: 'Sales Manager',
  department_id: 10,
  manager_id: null,
  location: null,
  start_date: null,
  roles: [],
}

const sessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: me } } }
const peopleRoute = { 'GET /api/companies/1/people': { body: { success: true, message: '', data: [ me, tunde ] } } }

const pendingLeave: Request = {
  id: 1,
  company_id: 1,
  requester_id: 98,
  kind: 'leave',
  payload: { start_date: '2026-12-22', end_date: '2026-12-29' },
  decision: 'require_approval',
  matched_rule_ids: [ 'leave_notice_period' ],
  policy_version: 1,
  status: 'pending',
  created_at: '2026-01-01T00:00:00Z',
  workflow_run: {
    id: 10,
    status: 'in_progress',
    current_step: 'manager_approval',
    step_runs: [
      { id: 100, step_key: 'manager_approval', reference: 'person:1', resolved_person_id: 1, status: 'pending', acted_at: null, overridden: false, override_reason: null },
    ],
  },
}

const autoApprovedExpense: Request = {
  id: 2,
  company_id: 1,
  requester_id: 98,
  kind: 'expense',
  payload: { amount_eur: 120, category: 'supplies' },
  decision: 'auto_approve',
  matched_rule_ids: [ 'small_expense' ],
  policy_version: 1,
  status: 'approved',
  created_at: '2025-12-15T00:00:00Z',
  workflow_run: null,
}

describe('/requests', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('asks for only the signed-in person\'s own requests', async () => {
    const fetchMock = mockApi({
      'GET /api/companies/1/requests?requester_id=98': { body: { success: true, message: '', data: [] } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/requests')

    expect(await screen.findByText(/haven.t submitted any requests/i)).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/requests?requester_id=98', expect.anything())
  })

  it('shows each request\'s kind, details, status and, while in flight, who it is waiting on', async () => {
    mockApi({
      'GET /api/companies/1/requests?requester_id=98': { body: { success: true, message: '', data: [ pendingLeave, autoApprovedExpense ] } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/requests')

    expect(await screen.findByText('Leave request')).toBeInTheDocument()
    expect(screen.getByText('Pending')).toBeInTheDocument()
    expect(screen.getByText('Manager approval · Tunde Bakare')).toBeInTheDocument()

    expect(screen.getByText('Expense request')).toBeInTheDocument()
    expect(screen.getByText('Approved')).toBeInTheDocument()
  })

  it('shows a plain empty state, not an error, when nothing has been submitted', async () => {
    mockApi({
      'GET /api/companies/1/requests?requester_id=98': { body: { success: true, message: '', data: [] } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/requests')

    expect(await screen.findByText(/haven.t submitted any requests/i)).toBeInTheDocument()
  })
})
