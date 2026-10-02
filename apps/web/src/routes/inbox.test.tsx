import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Person, Request } from 'api-types'
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

const leaveRequest: Request = {
  id: 1,
  company_id: 1,
  requester_id: 3,
  kind: 'leave',
  payload: { start_date: '2026-12-22', end_date: '2026-12-29' },
  decision: 'require_approval',
  matched_rule_ids: ['leave_notice_period'],
  policy_version: 1,
  status: 'pending',
  created_at: '2026-01-01T00:00:00Z',
  workflow_run: {
    id: 10,
    status: 'in_progress',
    current_step: 'manager_approval',
    step_runs: [
      {
        id: 100,
        step_key: 'manager_approval',
        reference: 'person:1',
        resolved_person_id: 1,
        status: 'pending',
        acted_at: null,
        overridden: false,
        override_reason: null,
      },
    ],
  },
}

const unresolvedRequest: Request = {
  ...leaveRequest,
  id: 2,
  workflow_run: {
    id: 11,
    status: 'in_progress',
    current_step: 'office_task',
    step_runs: [
      {
        id: 101,
        step_key: 'office_task',
        reference: 'role:office_manager',
        resolved_person_id: null,
        status: 'pending',
        acted_at: null,
        overridden: false,
        override_reason: null,
      },
    ],
  },
}

const peopleRoute = { 'GET /api/companies/1/people': { body: { success: true, message: '', data: people } } }

describe('/inbox', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when no company has been selected yet', async () => {
    await renderApp('/inbox')

    expect(await screen.findByRole('heading', { name: 'Inbox' })).toBeInTheDocument()
    expect(screen.getByText(/assemble one on the assemble page first/i)).toBeInTheDocument()
  })

  it('shows an empty state when nothing is waiting on anyone', async () => {
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/requests': { body: { success: true, message: '', data: [] } },
      ...peopleRoute,
    })

    await renderApp('/inbox')

    expect(await screen.findByText(/all caught up/i)).toBeInTheDocument()
  })

  it('only lists step runs that have actually been resolved and assigned', async () => {
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/requests': {
        body: { success: true, message: '', data: [leaveRequest, unresolvedRequest] },
      },
      ...peopleRoute,
    })

    await renderApp('/inbox')

    expect(await screen.findByText('Leave request from Ngozi Doe')).toBeInTheDocument()
    expect(screen.getAllByText('Leave request from Ngozi Doe')).toHaveLength(1)
  })

  it('approves a step run and refreshes the list', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const acted = {
      id: 100,
      step_key: 'manager_approval',
      reference: 'person:1',
      resolved_person_id: 1,
      status: 'done' as const,
      acted_at: '2026-01-02T00:00:00Z',
      overridden: false,
      override_reason: null,
    }
    mockApi({
      'GET /api/companies/1/requests': [
        { body: { success: true, message: '', data: [leaveRequest] } },
        { body: { success: true, message: '', data: [{ ...leaveRequest, workflow_run: { ...leaveRequest.workflow_run, step_runs: [acted] } }] } },
      ],
      'POST /api/step_runs/100/act': { body: { success: true, message: 'Step updated.', data: acted } },
      ...peopleRoute,
    })

    await renderApp('/inbox')
    await user.click(await screen.findByRole('button', { name: 'Approve' }))

    expect(await screen.findByText(/all caught up/i)).toBeInTheDocument()
  })

  it('overrides a step run only once a reason is given', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/requests': { body: { success: true, message: '', data: [leaveRequest] } },
      'POST /api/step_runs/100/act': {
        body: { success: true, message: 'Step updated.', data: { ...leaveRequest.workflow_run!.step_runs[0], overridden: true } },
      },
      ...peopleRoute,
    })

    await renderApp('/inbox')
    await user.click(await screen.findByRole('button', { name: 'Override' }))

    const confirmButton = screen.getByRole('button', { name: 'Confirm override' })
    expect(confirmButton).toBeDisabled()

    await user.type(screen.getByLabelText("Reason for overriding the engine's decision"), 'Manager is out sick')
    expect(confirmButton).toBeEnabled()
  })

  it('filters by the acting person', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const expenseRequest: Request = {
      ...leaveRequest,
      id: 3,
      kind: 'expense',
      requester_id: 1,
      workflow_run: {
        id: 12,
        status: 'in_progress',
        current_step: 'finance_approval',
        step_runs: [
          {
            id: 102,
            step_key: 'finance_approval',
            reference: 'person:2',
            resolved_person_id: 2,
            status: 'pending',
            acted_at: null,
            overridden: false,
            override_reason: null,
          },
        ],
      },
    }
    mockApi({
      'GET /api/companies/1/requests': { body: { success: true, message: '', data: [leaveRequest, expenseRequest] } },
      ...peopleRoute,
    })

    await renderApp('/inbox')
    expect(await screen.findByText('Leave request from Ngozi Doe')).toBeInTheDocument()
    expect(screen.getByText('Expense request from Tunde Bakare')).toBeInTheDocument()

    await user.selectOptions(screen.getByLabelText('Acting as'), 'Tunde Bakare')
    expect(await screen.findByText('Leave request from Ngozi Doe')).toBeInTheDocument()
    expect(screen.queryByText('Expense request from Tunde Bakare')).not.toBeInTheDocument()
  })
})
