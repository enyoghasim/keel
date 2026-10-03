import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Person, Workflow, WorkflowChangeProposal, WorkflowEdit, WorkflowTestRunResult } from 'api-types'
import { act } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'
import { chooseOption } from '../test/choose-option'

// Same stable-spy setup as trust.test.tsx and insights.test.tsx.
const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))
const lastSubscription = () => subscriptionsCreate.mock.calls[subscriptionsCreate.mock.calls.length - 1]

const expenseWorkflow: Workflow = {
  id: 5,
  name: 'Expense approval',
  status: 'active',
  version: 1,
  trigger: { request_kind: 'expense' },
  steps: [
    { key: 'approval', type: 'approval' },
    {
      key: 'notify_finance',
      type: 'notify',
      title: 'Notify finance',
      assignee: 'role:finance_lead',
      when: { field: 'payload.amount_eur', op: 'gt', value: 1000 },
    },
  ],
  created_at: '2026-01-01T00:00:00Z',
}

const leaveWorkflow: Workflow = {
  id: 6,
  name: 'Leave approval',
  status: 'draft',
  version: 1,
  trigger: { request_kind: 'leave' },
  steps: [{ key: 'approval', type: 'approval' }],
  created_at: '2026-01-02T00:00:00Z',
}

const requester: Person = {
  id: 2,
  name: 'Ngozi Doe',
  email: 'ngozi@factorial.test',
  title: 'Sales Rep',
  department_id: null,
  manager_id: null,
  location: null,
  start_date: null,
  roles: [],
}
const peopleRoute = { 'GET /api/companies/1/people': { body: { success: true, message: '', data: [requester] } } }

const currentPerson: Person = {
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
const sessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: currentPerson } } }

describe('/workflows', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when the company has no workflows', async () => {
    mockApi({ 'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [] } }, ...sessionRoute })

    await renderApp('/workflows')

    expect(await screen.findByText(/no workflows yet/i)).toBeInTheDocument()
  })

  it('shows the first workflow selected, with its trigger and steps on the graph', async () => {
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow, leaveWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')

    expect(await screen.findByRole('tab', { name: /Expense approval/ })).toHaveAttribute('aria-selected', 'true')
    expect(await screen.findByText('Expense request submitted')).toBeInTheDocument()
    expect(screen.getByText('Notify finance')).toBeInTheDocument()
  })

  it('switches workflows when a different tab is picked', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow, leaveWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      'GET /api/companies/1/workflows/6': { body: { success: true, message: '', data: leaveWorkflow } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')
    await screen.findByText('Expense request submitted')

    await user.click(screen.getByRole('tab', { name: /Leave approval/ }))

    expect(await screen.findByText('Leave request submitted')).toBeInTheDocument()
  })

  it('shows the draft warning and a Publish button only for a draft workflow, and only to an hr_admin', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow, leaveWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      'GET /api/companies/1/workflows/6': { body: { success: true, message: '', data: leaveWorkflow } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')
    await screen.findByText('Expense request submitted')
    expect(screen.queryByText(/not yet enforced/)).not.toBeInTheDocument()

    await user.click(screen.getByRole('tab', { name: /Leave approval/ }))

    expect(await screen.findByText(/not yet enforced/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Publish' })).toBeInTheDocument()
  })

  it('hides the draft warning from a non-hr_admin', async () => {
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [leaveWorkflow] } },
      'GET /api/companies/1/workflows/6': { body: { success: true, message: '', data: leaveWorkflow } },
      ...peopleRoute,
      'GET /api/companies/1/session': { body: { success: true, message: '', data: { ...currentPerson, roles: [] } } },
    })

    await renderApp('/workflows')

    await screen.findByText('Leave request submitted')
    expect(screen.queryByText(/not yet enforced/)).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Publish' })).not.toBeInTheDocument()
  })

  it('publishes a draft workflow and clears the warning once it refetches as active', async () => {
    const user = userEvent.setup()
    const published = { ...leaveWorkflow, status: 'active' as const, version: 2 }
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [leaveWorkflow] } },
      'GET /api/companies/1/workflows/6': [
        { body: { success: true, message: '', data: leaveWorkflow } },
        { body: { success: true, message: '', data: published } },
      ],
      'POST /api/companies/1/workflows/6/publish': { body: { success: true, message: '', data: published } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')
    await screen.findByText(/not yet enforced/)

    await user.click(screen.getByRole('button', { name: 'Publish' }))

    await waitFor(() => expect(screen.queryByText(/not yet enforced/)).not.toBeInTheDocument())
  })

  it('runs a test run and lights up the matched steps with the resolved person', async () => {
    const user = userEvent.setup()
    const testRunResult: WorkflowTestRunResult = {
      outcome: 'require_approval',
      matched_rule_keys: ['big_expense'],
      errors: [],
      steps: [
        { step_key: 'approval', type: 'approval', reference: 'person:2', resolved_person_id: 2, matched: true },
        { step_key: 'notify_finance', type: 'notify', reference: 'role:finance_lead', resolved_person_id: null, matched: true },
      ],
    }
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      'POST /api/companies/1/workflows/5/test_run': { body: { success: true, message: '', data: testRunResult } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')
    await screen.findByText('Expense request submitted')

    await user.click(screen.getByRole('button', { name: 'Test run' }))
    await chooseOption(user, await screen.findByLabelText('Requester'), 'Ngozi Doe')
    await user.type(screen.getByLabelText('Amount (EUR)'), '1500')
    await user.click(screen.getByRole('button', { name: 'Run test' }))

    expect(await screen.findByText('Needs approval')).toBeInTheDocument()
    expect(screen.getByText('Ngozi Doe')).toBeInTheDocument()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  describe('describe a change', () => {
    const pendingEdit: WorkflowEdit = {
      id: 31, workflow_id: 5, instruction: 'IT sets up accounts after the manager approves', source: 'instruction', status: 'pending',
      change_proposal_id: null, error_message: null, created_at: '2026-10-02T00:00:00Z',
    }
    const proposal: WorkflowChangeProposal = {
      id: 8, company_id: 1, kind: 'workflow', title: 'Expense approval: Added an IT step', proposed_by: 'user', agent_run_id: null,
      status: 'pending', decided_by_id: null, decided_at: null, explanation: null, created_at: '2026-10-02T00:00:00Z',
      diff: {
        workflow_id: 5, request_kind: 'expense', instruction: pendingEdit.instruction, before: expenseWorkflow.steps,
        after: [...expenseWorkflow.steps, { key: 'it_setup', type: 'task', title: 'Set up accounts', assignee: 'role:it_admin' }],
      },
      impact: { steps: { added: ['it_setup'], removed: [], changed: [], moved: [] }, scenarios_run: 3, affected_count: 0, affected: [], broken: [], in_flight: 0 },
    }
    const routes = {
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      'POST /api/companies/1/workflows/5/edits': { status: 202, body: { success: true, message: '', data: pendingEdit } },
      ...peopleRoute,
      ...sessionRoute,
    }

    async function describeChange(user: ReturnType<typeof userEvent.setup>) {
      await screen.findByText('Expense request submitted')
      await user.type(screen.getByRole('textbox', { name: 'Describe a change' }), pendingEdit.instruction!)
      await user.click(screen.getByRole('button', { name: 'Propose change' }))
    }

    it('sends the instruction, then shows the proposed graph once the draft arrives, without changing anything', async () => {
      const user = userEvent.setup()
      const fetchMock = mockApi({
        ...routes,
        'GET /api/companies/1/change_proposals/8': { body: { success: true, message: '', data: proposal } },
      })

      await renderApp('/workflows')
      await describeChange(user)

      expect(await screen.findByRole('button', { name: 'Drafting…' })).toBeDisabled()
      expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/workflows/5/edits', expect.objectContaining({ body: JSON.stringify({ instruction: pendingEdit.instruction }) }))

      expect(lastSubscription()[0]).toMatchObject({ channel: 'WorkflowEditChannel', workflow_edit_id: 31 })
      act(() => lastSubscription()[1].received({ ...pendingEdit, status: 'proposed', change_proposal_id: 8 }))

      expect(await screen.findByText('Expense approval: Added an IT step')).toBeInTheDocument()
      expect(await screen.findAllByText('Set up accounts')).not.toHaveLength(0)
      expect(screen.getByText('Added')).toBeInTheDocument()
      expect(screen.getByRole('link', { name: /review and approve it on proposals/i })).toHaveAttribute('href', '/proposals')
      expect(screen.getByRole('button', { name: 'Propose change' })).toBeEnabled()
    })

    it("shows why a draft failed, and says when the instruction wouldn't change anything", async () => {
      const user = userEvent.setup()
      mockApi(routes)

      await renderApp('/workflows')
      await describeChange(user)
      await screen.findByRole('button', { name: 'Drafting…' })

      act(() => lastSubscription()[1].received({ ...pendingEdit, status: 'failed', error_message: "Keel couldn't turn that into a valid workflow." }))
      expect(await screen.findByText("Keel couldn't turn that into a valid workflow.")).toBeInTheDocument()

      await user.click(screen.getByRole('button', { name: 'Propose change' }))
      act(() => lastSubscription()[1].received({ ...pendingEdit, status: 'unchanged' }))
      expect(await screen.findByText(/wouldn't change this workflow/)).toBeInTheDocument()
    })

    it('is for hr_admins only', async () => {
      mockApi({
        ...routes,
        'GET /api/companies/1/session': { body: { success: true, message: '', data: { ...currentPerson, roles: [] } } },
      })

      await renderApp('/workflows')

      await screen.findByText('Expense request submitted')
      expect(screen.queryByRole('textbox', { name: 'Describe a change' })).not.toBeInTheDocument()
    })
  })

  // The editor's active-path ("Propose change") feeds steps instead of an
  // instruction into the same workflow_edits → Change Proposal pipeline,
  // and lands on the exact same review UI "describe a change" does above.
  describe('edit steps directly', () => {
    const editedEdit: WorkflowEdit = {
      id: 32, workflow_id: 5, instruction: null, source: 'steps', status: 'pending',
      change_proposal_id: null, error_message: null, created_at: '2026-10-02T00:00:00Z',
    }
    const editedProposal: WorkflowChangeProposal = {
      id: 9, company_id: 1, kind: 'workflow', title: 'Expense approval: edited directly', proposed_by: 'user', agent_run_id: null,
      status: 'pending', decided_by_id: null, decided_at: null, explanation: null, created_at: '2026-10-02T00:00:00Z',
      diff: { workflow_id: 5, request_kind: 'expense', instruction: null, before: expenseWorkflow.steps, after: [ expenseWorkflow.steps[0] ] },
      impact: { steps: { added: [], removed: [ 'notify_finance' ], changed: [], moved: [] }, scenarios_run: 3, affected_count: 0, affected: [], broken: [], in_flight: 0 },
    }

    it('proposes a step deletion and shows the same proposal review UI as describe a change', async () => {
      const user = userEvent.setup()
      const fetchMock = mockApi({
        'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [ expenseWorkflow ] } },
        'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
        'GET /api/companies/1/integrations': { body: { success: true, message: '', data: [] } },
        'POST /api/companies/1/workflows/5/edits': { status: 202, body: { success: true, message: '', data: editedEdit } },
        'GET /api/companies/1/change_proposals/9': { body: { success: true, message: '', data: editedProposal } },
        ...peopleRoute,
        ...sessionRoute,
      })

      await renderApp('/workflows')
      await screen.findByText('Expense request submitted')

      await user.click(screen.getByRole('button', { name: 'Edit steps' }))
      await user.click(screen.getByRole('button', { name: 'Edit' }))
      await user.click(screen.getByRole('button', { name: 'Delete step' }))
      await user.click(screen.getByRole('button', { name: 'Propose these steps' }))

      expect(fetchMock).toHaveBeenCalledWith(
        '/api/companies/1/workflows/5/edits',
        expect.objectContaining({ method: 'POST', body: JSON.stringify({ steps: [ expenseWorkflow.steps[0] ] }) }),
      )
      act(() => lastSubscription()[1].received({ ...editedEdit, status: 'proposed', change_proposal_id: 9 }))

      expect(await screen.findByText('Expense approval: edited directly')).toBeInTheDocument()
      expect(screen.getByRole('link', { name: /review and approve it on proposals/i })).toHaveAttribute('href', '/proposals')
    })
  })
})
