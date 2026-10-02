import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Person, Request } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'
import { chooseOption } from '../test/choose-option'

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

// Distinct from `people` above, so the Topbar's signed-in chip doesn't add
// an extra occurrence of a name these tests already assert on.
const hrAdmin: Person = {
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
const hrAdminSessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: hrAdmin } } }

// A plain employee, also assigned the leave request's step — used for the
// "scoped to yourself" tests, distinct from both `people` and `hrAdmin`.
const tundeAsSelf: Person = { ...people[0], id: 98, name: 'Tunde Okafor' }
const selfSessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: tundeAsSelf } } }

const assignedToSelf: Request = {
  ...leaveRequest,
  workflow_run: {
    ...leaveRequest.workflow_run!,
    step_runs: [ { ...leaveRequest.workflow_run!.step_runs[0], resolved_person_id: 98 } ],
  },
}

describe('/inbox', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when nothing is waiting on anyone', async () => {
    mockApi({
      'GET /api/companies/1/requests': { body: { success: true, message: '', data: [] } },
      ...peopleRoute,
      ...selfSessionRoute,
    })

    await renderApp('/inbox')

    expect(await screen.findByText(/all caught up/i)).toBeInTheDocument()
  })

  describe('as a plain employee', () => {
    it('shows only steps assigned to the signed-in person, with no acting-as switch', async () => {
      mockApi({
        'GET /api/companies/1/requests': { body: { success: true, message: '', data: [assignedToSelf, unresolvedRequest] } },
        ...peopleRoute,
        ...selfSessionRoute,
      })

      await renderApp('/inbox')

      expect(await screen.findByText('Leave request from Ngozi Doe')).toBeInTheDocument()
      expect(screen.queryByLabelText('Acting as')).not.toBeInTheDocument()
    })

    it('shows a waiting-on-you empty state when nothing is assigned to them, even if other steps are pending', async () => {
      mockApi({
        'GET /api/companies/1/requests': { body: { success: true, message: '', data: [leaveRequest] } },
        ...peopleRoute,
        ...selfSessionRoute,
      })

      await renderApp('/inbox')

      expect(await screen.findByText(/nothing is waiting on you/i)).toBeInTheDocument()
      expect(screen.queryByText('Leave request from Ngozi Doe')).not.toBeInTheDocument()
    })

    it('approves a step run assigned to them and refreshes the list', async () => {
      const user = userEvent.setup()
      const acted = {
        id: 100,
        step_key: 'manager_approval',
        reference: 'person:98',
        resolved_person_id: 98,
        status: 'done' as const,
        acted_at: '2026-01-02T00:00:00Z',
        overridden: false,
        override_reason: null,
      }
      mockApi({
        'GET /api/companies/1/requests': [
          { body: { success: true, message: '', data: [assignedToSelf] } },
          { body: { success: true, message: '', data: [{ ...assignedToSelf, workflow_run: { ...assignedToSelf.workflow_run, step_runs: [acted] } }] } },
        ],
        'POST /api/step_runs/100/act': { body: { success: true, message: 'Step updated.', data: acted } },
        ...peopleRoute,
        ...selfSessionRoute,
      })

      await renderApp('/inbox')
      await user.click(await screen.findByRole('button', { name: 'Approve' }))

      expect(await screen.findByText(/all caught up/i)).toBeInTheDocument()
    })
  })

  describe('as an hr_admin', () => {
    it('defaults to their own queue', async () => {
      mockApi({
        'GET /api/companies/1/requests': { body: { success: true, message: '', data: [leaveRequest] } },
        ...peopleRoute,
        ...hrAdminSessionRoute,
      })

      await renderApp('/inbox')

      expect(await screen.findByText(/nothing is waiting on you/i)).toBeInTheDocument()
      expect(screen.queryByText('Leave request from Ngozi Doe')).not.toBeInTheDocument()
    })

    it('can switch to Everyone to see every assigned step, including ones not assigned to them', async () => {
      const user = userEvent.setup()
      mockApi({
        'GET /api/companies/1/requests': { body: { success: true, message: '', data: [leaveRequest, unresolvedRequest] } },
        ...peopleRoute,
        ...hrAdminSessionRoute,
      })

      await renderApp('/inbox')
      await chooseOption(user, await screen.findByLabelText('Acting as'), 'Everyone')

      expect(await screen.findByText('Leave request from Ngozi Doe')).toBeInTheDocument()
      expect(screen.getAllByText('Leave request from Ngozi Doe')).toHaveLength(1)
    })

    it('can switch to a specific assignee to see just their queue', async () => {
      const user = userEvent.setup()
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
        ...hrAdminSessionRoute,
      })

      await renderApp('/inbox')
      await chooseOption(user, await screen.findByLabelText('Acting as'), 'Tunde Bakare')

      expect(await screen.findByText('Leave request from Ngozi Doe')).toBeInTheDocument()
      expect(screen.queryByText('Expense request from Tunde Bakare')).not.toBeInTheDocument()
    })

    it('can approve a step assigned to someone else', async () => {
      const user = userEvent.setup()
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
        ...hrAdminSessionRoute,
      })

      await renderApp('/inbox')
      await chooseOption(user, await screen.findByLabelText('Acting as'), 'Everyone')
      await user.click(await screen.findByRole('button', { name: 'Approve' }))

      expect(await screen.findByText(/all caught up/i)).toBeInTheDocument()
    })
  })

  it('overrides a step run only once a reason is given', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/requests': { body: { success: true, message: '', data: [assignedToSelf] } },
      'POST /api/step_runs/100/act': {
        body: { success: true, message: 'Step updated.', data: { ...assignedToSelf.workflow_run!.step_runs[0], overridden: true } },
      },
      ...peopleRoute,
      ...selfSessionRoute,
    })

    await renderApp('/inbox')
    await user.click(await screen.findByRole('button', { name: 'Override' }))

    const confirmButton = screen.getByRole('button', { name: 'Confirm override' })
    expect(confirmButton).toBeDisabled()

    await user.type(screen.getByLabelText("Reason for overriding the engine's decision"), 'Manager is out sick')
    expect(confirmButton).toBeEnabled()
  })
})
