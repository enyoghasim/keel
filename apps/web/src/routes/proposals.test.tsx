import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { AgentRun, Department, OrgChangeProposal, Person, RuleChangeProposal, WorkflowChangeProposal } from 'api-types'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { setCurrentCompanyId } from '../lib/current-company'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

// The page subscribes to Action Cable; keep jsdom from opening a socket.
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: vi.fn(() => ({ unsubscribe: vi.fn() })) } })),
}))

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

const cleanProposal: OrgChangeProposal = {
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
  agent_run_id: null,
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  explanation: null,
  created_at: '2026-01-01T00:00:00Z',
}

const brokenProposal: OrgChangeProposal = {
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
  agent_run_id: null,
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  explanation: null,
  created_at: '2026-01-02T00:00:00Z',
}

const ruleProposal: RuleChangeProposal = {
  id: 3,
  company_id: 1,
  kind: 'rule',
  title: 'Expense Policy: Raise the limit to €800',
  proposed_by: 'agent',
  agent_run_id: 5,
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  explanation: null,
  created_at: '2026-01-03T00:00:00Z',
  diff: {
    policy_id: 1,
    instruction: 'Raise the limit to €800',
    before: [
      {
        key: 'expense_small_auto',
        priority: 10,
        conditions: { field: 'payload.amount_eur', op: 'lte', value: 500 },
        actions: { decision: 'auto_approve' },
        source_quote: 'Expenses up to €500 are auto-approved.',
        source_chunk_id: 1,
      },
    ],
    after: [
      {
        key: 'expense_small_auto',
        priority: 10,
        conditions: { field: 'payload.amount_eur', op: 'lte', value: 800 },
        actions: { decision: 'auto_approve' },
        source_quote: 'Expenses up to €500 are auto-approved.',
        source_chunk_id: 1,
      },
    ],
  },
  impact: {
    backtest: {
      kind: 'expense',
      total: 4,
      new_conflicts: [],
      flipped_count: 1,
      summary: 'This would have changed 1 of 4 past expense decisions: 1 would have been auto-approved instead of sent for approval.',
      flipped: [{ request_id: 9, requester_id: 3, payload: { amount_eur: 700 }, before: 'require_approval', after: 'auto_approve' }],
    },
  },
}

const workflowProposal: WorkflowChangeProposal = {
  id: 4,
  company_id: 1,
  kind: 'workflow',
  title: 'Leave Workflow: Added an IT step',
  proposed_by: 'user',
  agent_run_id: null,
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  explanation: null,
  created_at: '2026-01-04T00:00:00Z',
  diff: {
    workflow_id: 5,
    request_kind: 'leave',
    instruction: 'IT sets up accounts after the manager approves',
    before: [{ key: 'approval', type: 'approval', assignee: 'manager_of(requester)' }],
    after: [
      { key: 'approval', type: 'approval', assignee: 'manager_of(requester)' },
      { key: 'it_setup', type: 'task', title: 'Set up accounts', assignee: 'role:it_admin' },
    ],
  },
  impact: {
    steps: { added: ['it_setup'], removed: [], changed: [], moved: [] },
    scenarios_run: 3,
    affected_count: 3,
    affected: [],
    broken: [{ step_key: 'it_setup', reference: 'role:it_admin', person_count: 3 }],
    in_flight: 0,
  },
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

  it('shows people who are not hr_admins that a proposal awaits an HR admin, without decision buttons', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [cleanProposal] } },
      ...peopleRoute,
      ...departmentsRoute,
      'GET /api/companies/1/session': { body: { success: true, message: '', data: { ...currentPerson, roles: [] } } },
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))

    expect(screen.getByText(/waiting for an hr admin/i)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Approve' })).not.toBeInTheDocument()
  })

  it('sends the reason typed for a rejection, which the API turns into a candidate test case', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const rejected = { ...cleanProposal, status: 'rejected' as const, decided_at: '2026-01-03T00:00:00Z' }
    const fetchMock = mockApi({
      'GET /api/companies/1/change_proposals': [
        { body: { success: true, message: '', data: [cleanProposal] } },
        { body: { success: true, message: '', data: [rejected] } },
      ],
      'POST /api/companies/1/change_proposals/1/reject': { body: { success: true, message: '', data: rejected } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))
    await user.type(screen.getByLabelText('Reason for rejecting (optional)'), 'Ada is on leave')
    await user.click(screen.getByRole('button', { name: 'Reject' }))

    await screen.findByText(/this proposal was rejected/i)
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/change_proposals/1/reject',
      expect.objectContaining({ body: JSON.stringify({ reason: 'Ada is on leave' }) }),
    )
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

  it('lists a rule proposal with its flipped count and expands it to the backtest, with Approve enabled', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [ruleProposal] } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')

    expect(await screen.findByText(/Rule change · proposed by Keel agent/)).toBeInTheDocument()
    expect(screen.getByText('1 decision flipped')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /Raise the limit to €800/ }))

    expect(await screen.findByText(/would have changed 1 of 4 past expense decisions/)).toBeInTheDocument()
    expect(screen.getByRole('group', { name: 'expense_small_auto after' })).toHaveTextContent('amount ≤ €800')
    expect(screen.getByRole('button', { name: 'Approve' })).toBeEnabled()
  })

  it('lists a workflow proposal with its graph, and holds Approve behind a reason while a new step resolves to nobody', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [workflowProposal] } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')

    expect(await screen.findByText(/Workflow change · proposed by a person/)).toBeInTheDocument()
    expect(screen.getByText('3 people affected')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /Added an IT step/ }))

    expect(await screen.findByText('Set up accounts')).toBeInTheDocument()
    expect(screen.getByText(/role:it_admin resolves to nobody for 3 people/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Approve' })).toBeDisabled()
  })

  it('holds a rule proposal that creates a conflict behind Approve anyway with a reason', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const conflicted: RuleChangeProposal = {
      ...ruleProposal,
      impact: {
        backtest: {
          ...ruleProposal.impact.backtest,
          new_conflicts: [{ rules: ['expense_small_auto', 'expense_travel'], example: { amount_eur: 700 }, warning: 'These two rules now overlap at the same priority.' }],
        },
      },
    }
    const fetchMock = mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [conflicted] } },
      'POST /api/companies/1/change_proposals/3/approve': { body: { success: true, message: '', data: { ...conflicted, status: 'approved' } } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Raise the limit to €800/ }))

    const approveButton = await screen.findByRole('button', { name: 'Approve' })
    expect(approveButton).toBeDisabled()
    await user.click(screen.getByRole('checkbox', { name: /Approve anyway, despite 1 new conflict/ }))
    await user.type(screen.getByLabelText('Reason for approving anyway'), 'Merging travel rules next week')
    expect(approveButton).toBeEnabled()

    await user.click(approveButton)
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/change_proposals/3/approve',
      expect.objectContaining({ body: JSON.stringify({ approve_anyway: true, reason: 'Merging travel rules next week' }) }),
    )
  })

  it("lets an hr_admin open the trace of a proposal the agent made, and doesn't offer one for a person's", async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const run: AgentRun = {
      id: 5, conversation_id: 'c', person_id: 99, message: 'Raise the limit to €800', status: 'completed', final_text: 'Proposed.', total_tokens: 100,
      error_message: null, cost_usd: null, feedback: null, feedback_reason: null, created_at: '2026-01-03T00:00:00Z',
      steps: [{ id: 1, position: 1, kind: 'tool', tool_name: 'propose_rule_change', input: { policy_id: 1 }, output: { proposal_id: 3 }, latency_ms: 40, tokens: null }],
    }
    mockApi({
      'GET /api/companies/1/change_proposals': { body: { success: true, message: '', data: [ruleProposal, cleanProposal] } },
      'GET /api/companies/1/change_proposals/3/trace': { body: { success: true, message: '', data: run } },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))
    expect(screen.queryByRole('button', { name: 'View trace' })).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /Raise the limit to €800/ }))
    await user.click(await screen.findByRole('button', { name: 'View trace' }))

    const drawer = await screen.findByRole('dialog', { name: 'Agent trace' })
    expect(within(drawer).getByText('propose_rule_change')).toBeInTheDocument()
  })

  it('shows the plain-English explanation of a proposal, once it has one', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/change_proposals': {
        body: { success: true, message: '', data: [{ ...cleanProposal, explanation: 'Ngozi’s requests would go to Ada instead of Tunde.' }, brokenProposal] },
      },
      ...peopleRoute,
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))
    expect(within(screen.getByRole('region', { name: 'In plain English' })).getByText(/requests would go to Ada instead of Tunde/)).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: /Remove Sales department head/ }))

    expect(screen.getAllByRole('region', { name: 'In plain English' })).toHaveLength(1)
  })
})
