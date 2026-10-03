import { render, screen, within } from '@testing-library/react'
import type { Person, WorkflowChangeProposal } from 'api-types'
import { describe, expect, it } from 'vitest'
import { WorkflowProposalDetails } from './workflow-proposal-details'

const approval = { key: 'approval', type: 'approval' as const, assignee: 'manager_of(requester)' }
const notify = { key: 'hr_notify', type: 'notify' as const, assignee: 'role:hr_admin' }
const itStep = { key: 'it_setup', type: 'task' as const, title: 'Set up accounts', assignee: 'role:it_admin' }

const proposal: WorkflowChangeProposal = {
  id: 9,
  company_id: 1,
  kind: 'workflow',
  title: 'Leave Workflow: Added an IT step',
  proposed_by: 'user',
  agent_run_id: null,
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  explanation: null,
  created_at: '2026-10-02T00:00:00Z',
  diff: { workflow_id: 5, request_kind: 'leave', instruction: 'IT sets up accounts after the manager approves', before: [approval, notify], after: [approval, itStep, notify] },
  impact: {
    steps: { added: ['it_setup'], removed: [], changed: [], moved: [] },
    scenarios_run: 6,
    affected_count: 2,
    affected: [
      {
        person_id: 3,
        payload: { days: 5 },
        before: [{ step_key: 'approval', reference: 'person:1', person_id: 1 }],
        after: [
          { step_key: 'approval', reference: 'person:1', person_id: 1 },
          { step_key: 'it_setup', reference: 'role:it_admin', person_id: 4 },
        ],
      },
    ],
    broken: [],
    in_flight: 0,
  },
}

const person = (id: number, name: string): Person => ({
  id, name, email: `${id}@factorial.test`, title: null, department_id: null, manager_id: null, location: null, start_date: null, roles: [],
})
const people = new Map([person(3, 'Ngozi Doe'), person(4, 'Femi IT')].map((p) => [p.id, p]))

describe('WorkflowProposalDetails', () => {
  it('quotes the instruction and shows the proposed graph with the added step marked', async () => {
    render(<WorkflowProposalDetails proposal={proposal} people={people} />)

    expect(screen.getByText(/IT sets up accounts after the manager approves/)).toBeInTheDocument()
    expect(await screen.findByText('Set up accounts')).toBeInTheDocument()
    expect(screen.getByText('Added')).toBeInTheDocument()
  })

  it('summarises the step changes and who is affected', () => {
    render(<WorkflowProposalDetails proposal={proposal} people={people} />)

    expect(within(screen.getByLabelText('Steps added')).getByText('1')).toBeInTheDocument()
    expect(within(screen.getByLabelText('People affected')).getByText('2')).toBeInTheDocument()
    expect(within(screen.getByLabelText('Broken steps')).getByText('0')).toBeInTheDocument()
  })

  it('names who a new step resolves to, for a sample of affected people', () => {
    render(<WorkflowProposalDetails proposal={proposal} people={people} />)

    const row = screen.getByRole('row', { name: /Ngozi Doe/ })
    expect(within(row).getByText(/it_setup → Femi IT/)).toBeInTheDocument()
  })

  it('warns about a new step that resolves to nobody', () => {
    const broken = { ...proposal, impact: { ...proposal.impact, broken: [{ step_key: 'it_setup', reference: 'role:it_admin', person_count: 12 }] } }
    render(<WorkflowProposalDetails proposal={broken} people={people} />)

    expect(screen.getByRole('list', { name: /problems/i })).toHaveTextContent('it_setup: role:it_admin resolves to nobody for 12 people')
  })

  it('warns about open requests sitting on a removed step', () => {
    const inFlight = { ...proposal, impact: { ...proposal.impact, in_flight: 2 } }
    render(<WorkflowProposalDetails proposal={inFlight} people={people} />)

    expect(screen.getByText(/2 open requests are waiting on a step this removes/)).toBeInTheDocument()
  })
})
