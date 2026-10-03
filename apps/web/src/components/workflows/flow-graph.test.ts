import type { Workflow, WorkflowStep, WorkflowTestRunStep } from 'api-types'
import { describe, expect, it } from 'vitest'
import { buildFlowGraph, mergeWorkflowSteps } from './flow-graph'

function workflow(steps: WorkflowStep[]): Workflow {
  return {
    id: 1,
    name: 'Expense approval',
    status: 'active',
    version: 1,
    trigger: { request_kind: 'expense' },
    steps,
    created_at: '2026-01-01T00:00:00Z',
  }
}

const personName = (id: number) => `Person #${id}`

describe('buildFlowGraph', () => {
  it('creates a trigger node labelled from the request kind, with no run status before any test run', () => {
    const { nodes } = buildFlowGraph(workflow([]), null, personName)

    expect(nodes).toHaveLength(1)
    expect(nodes[0]).toMatchObject({ id: 'trigger', data: { kind: 'trigger', label: 'Expense request submitted', runStatus: null } })
  })

  it('creates one node per step, in left-to-right order', () => {
    const steps: WorkflowStep[] = [
      { key: 'approval', type: 'approval' },
      { key: 'notify_finance', type: 'notify', title: 'Notify finance', assignee: 'role:finance_lead' },
    ]
    const { nodes } = buildFlowGraph(workflow(steps), null, personName)

    expect(nodes.map((n) => n.id)).toEqual(['trigger', 'approval', 'notify_finance'])
    expect(nodes[1].position.x).toBeLessThan(nodes[2].position.x)
    expect(nodes[2].data).toMatchObject({ kind: 'notify', label: 'Notify finance', subtitle: 'role:finance_lead' })
  })

  it('chains edges from trigger through each step in sequence', () => {
    const steps: WorkflowStep[] = [{ key: 'approval', type: 'approval' }, { key: 'task_it', type: 'task', assignee: 'role:it_admin' }]
    const { edges } = buildFlowGraph(workflow(steps), null, personName)

    expect(edges).toEqual([
      expect.objectContaining({ source: 'trigger', target: 'approval' }),
      expect.objectContaining({ source: 'approval', target: 'task_it' }),
    ])
  })

  it('draws a dashed, labelled edge into a conditional step', () => {
    const steps: WorkflowStep[] = [
      {
        key: 'notify_lagos',
        type: 'notify',
        assignee: 'role:office_manager',
        when: { field: 'requester.location', op: 'eq', value: 'Lagos' },
      },
    ]
    const { edges } = buildFlowGraph(workflow(steps), null, personName)

    expect(edges[0].label).toBe('location is Lagos')
    expect(edges[0].style).toMatchObject({ strokeDasharray: '5 5' })
  })

  it('leaves an unconditional edge solid and unlabelled', () => {
    const steps: WorkflowStep[] = [{ key: 'approval', type: 'approval' }]
    const { edges } = buildFlowGraph(workflow(steps), null, personName)

    expect(edges[0].label).toBeUndefined()
    expect(edges[0].style).not.toHaveProperty('strokeDasharray')
  })

  it('marks a step matched by the test run and resolves its person into the subtitle', () => {
    const steps: WorkflowStep[] = [{ key: 'approval', type: 'approval' }]
    const testRun: WorkflowTestRunStep[] = [
      { step_key: 'approval', type: 'approval', reference: 'person:7', resolved_person_id: 7, matched: true },
    ]
    const { nodes } = buildFlowGraph(workflow(steps), testRun, personName)

    expect(nodes[1].data).toMatchObject({ runStatus: 'matched', subtitle: 'Person #7' })
  })

  it('marks a step skipped when its when condition did not fire for the test run', () => {
    const steps: WorkflowStep[] = [
      { key: 'notify_lagos', type: 'notify', assignee: 'role:office_manager', when: { field: 'requester.location', op: 'eq', value: 'Lagos' } },
    ]
    const testRun: WorkflowTestRunStep[] = [
      { step_key: 'notify_lagos', type: 'notify', reference: 'role:office_manager', resolved_person_id: null, matched: false },
    ]
    const { nodes } = buildFlowGraph(workflow(steps), testRun, personName)

    expect(nodes[1].data.runStatus).toBe('skipped')
  })

  it('joins multiple approvers for the same step into one subtitle', () => {
    const steps: WorkflowStep[] = [{ key: 'approval', type: 'approval' }]
    const testRun: WorkflowTestRunStep[] = [
      { step_key: 'approval', type: 'approval', reference: 'person:7', resolved_person_id: 7, matched: true },
      { step_key: 'approval', type: 'approval', reference: 'person:8', resolved_person_id: 8, matched: true },
    ]
    const { nodes } = buildFlowGraph(workflow(steps), testRun, personName)

    expect(nodes[1].data.subtitle).toBe('Person #7, Person #8')
  })
})

describe('mergeWorkflowSteps', () => {
  const approval: WorkflowStep = { key: 'approval', type: 'approval', assignee: 'manager_of(requester)' }
  const notify: WorkflowStep = { key: 'hr_notify', type: 'notify', assignee: 'role:hr_admin' }
  const itStep: WorkflowStep = { key: 'it_setup', type: 'task', assignee: 'role:it_admin' }

  it('marks an added step and keeps the proposed order', () => {
    const { steps, status } = mergeWorkflowSteps([approval, notify], [approval, itStep, notify])

    expect(steps.map((s) => s.key)).toEqual(['approval', 'it_setup', 'hr_notify'])
    expect(status).toEqual({ it_setup: 'added' })
  })

  it('keeps a removed step in the graph, where it used to be, marked removed', () => {
    const { steps, status } = mergeWorkflowSteps([approval, itStep, notify], [approval, notify])

    expect(steps.map((s) => s.key)).toEqual(['approval', 'it_setup', 'hr_notify'])
    expect(status).toEqual({ it_setup: 'removed' })
  })

  it('puts a removed first step back at the front', () => {
    const { steps } = mergeWorkflowSteps([itStep, approval], [approval])

    expect(steps.map((s) => s.key)).toEqual(['it_setup', 'approval'])
  })

  it('marks a step whose definition changed, showing its new definition', () => {
    const rerouted = { ...notify, assignee: 'role:finance_lead' }
    const { steps, status } = mergeWorkflowSteps([approval, notify], [approval, rerouted])

    expect(steps[1]).toEqual(rerouted)
    expect(status).toEqual({ hr_notify: 'changed' })
  })

  it('reports no changes for identical workflows', () => {
    expect(mergeWorkflowSteps([approval], [approval]).status).toEqual({})
  })
})

describe('buildFlowGraph with a diff', () => {
  it('carries each step\'s diff status onto its node', () => {
    const steps: WorkflowStep[] = [{ key: 'approval', type: 'approval' }, { key: 'task_it', type: 'task', assignee: 'role:it_admin' }]
    const { nodes } = buildFlowGraph(workflow(steps), null, personName, { task_it: 'added' })

    expect(nodes.find((n) => n.id === 'task_it')?.data.diffStatus).toBe('added')
    expect(nodes.find((n) => n.id === 'approval')?.data.diffStatus).toBeNull()
  })
})
