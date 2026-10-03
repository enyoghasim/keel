import { render, screen } from '@testing-library/react'
import type { Person, Workflow } from 'api-types'
import { describe, expect, it } from 'vitest'
import { FlowCanvas } from './flow-canvas'

// Same boundary as org-canvas.test.tsx: React Flow's real layout math isn't
// worth asserting on in jsdom. This just checks the component mounts and
// renders the right nodes for real data — buildFlowGraph's own logic
// (edges, run status, layout order) is covered in flow-graph.test.ts.

const workflow: Workflow = {
  id: 1,
  name: 'Expense approval',
  status: 'active',
  version: 1,
  trigger: { request_kind: 'expense' },
  steps: [
    { key: 'approval', type: 'approval' },
    { key: 'notify_finance', type: 'notify', title: 'Notify finance', assignee: 'role:finance_lead' },
  ],
  created_at: '2026-01-01T00:00:00Z',
}

const people: Person[] = []

describe('FlowCanvas', () => {
  it('mounts and renders the trigger node and one node per step', async () => {
    render(<FlowCanvas workflow={workflow} people={people} />)

    expect(await screen.findByText('Expense request submitted')).toBeInTheDocument()
    expect(screen.getByText('Approval')).toBeInTheDocument()
    expect(screen.getByText('Notify finance')).toBeInTheDocument()
  })

  it('resolves a test run step to the matching person name', async () => {
    const testRun = [{ step_key: 'approval', type: 'approval', reference: 'person:1', resolved_person_id: 1, matched: true }]
    render(
      <FlowCanvas
        workflow={workflow}
        people={[{ id: 1, name: 'Tunde Bakare', email: 't@factorial.test', title: null, department_id: null, manager_id: null, location: null, start_date: null, roles: [] }]}
        testRun={testRun}
      />,
    )

    expect(await screen.findByText('Tunde Bakare')).toBeInTheDocument()
  })
})
