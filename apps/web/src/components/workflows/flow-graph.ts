import type { Workflow, WorkflowStep, WorkflowStepType, WorkflowTestRunStep } from 'api-types'
import { MarkerType, type Edge, type Node } from '@xyflow/react'
import { describeCondition } from '../policies/describe-rule'

export const NODE_WIDTH = 216
export const NODE_HEIGHT = 64
const X_GAP = 96

export type FlowNodeKind = 'trigger' | WorkflowStepType

export interface FlowNodeData extends Record<string, unknown> {
  kind: FlowNodeKind
  label: string
  subtitle: string | null
  /** From a test run: present once that step has been previewed, absent before any run. */
  runStatus: 'matched' | 'skipped' | null
}

function humanizeRequestKind(kind: string): string {
  return `${kind.charAt(0).toUpperCase()}${kind.slice(1)} request submitted`
}

function stepRunStatus(step: WorkflowStep, testRunSteps: WorkflowTestRunStep[] | null): FlowNodeData['runStatus'] {
  if (testRunSteps === null) return null
  const previews = testRunSteps.filter((s) => s.step_key === step.key)
  if (previews.length === 0) return null
  return previews.some((p) => p.matched) ? 'matched' : 'skipped'
}

function stepSubtitle(step: WorkflowStep, testRunSteps: WorkflowTestRunStep[] | null, personName: (id: number) => string): string | null {
  if (testRunSteps !== null) {
    const resolved = testRunSteps.filter((s) => s.step_key === step.key && s.resolved_person_id !== null)
    if (resolved.length > 0) return resolved.map((s) => personName(s.resolved_person_id as number)).join(', ')
  }

  if (step.type === 'approval') return null
  return step.assignee ?? null
}

/**
 * Builds the left-to-right step graph for /workflows (SPEC.md section 8):
 * a trigger node, then one node per step. Steps run strictly in sequence —
 * the runtime has no branching — so the layout is a simple chain rather
 * than something dagre needs to compute. A conditional step (one with a
 * `when`) gets a dashed, labelled edge in from the previous node.
 *
 * `testRun`, when present, lights up matched steps and greys out skipped
 * ones in the order Workflows::Runtime#dry_run resolved them.
 */
export function buildFlowGraph(
  workflow: Workflow,
  testRun: WorkflowTestRunStep[] | null,
  personName: (id: number) => string,
): { nodes: Node<FlowNodeData>[]; edges: Edge[] } {
  const triggerRunStatus: FlowNodeData['runStatus'] = testRun === null ? null : 'matched'

  const nodes: Node<FlowNodeData>[] = [
    {
      id: 'trigger',
      type: 'flowStep',
      position: { x: 0, y: 0 },
      data: {
        kind: 'trigger',
        label: humanizeRequestKind(workflow.trigger.request_kind),
        subtitle: null,
        runStatus: triggerRunStatus,
      },
    },
    ...workflow.steps.map((step, index) => ({
      id: step.key,
      type: 'flowStep',
      position: { x: (index + 1) * (NODE_WIDTH + X_GAP), y: 0 },
      data: {
        kind: step.type,
        label: step.title ?? step.key,
        subtitle: stepSubtitle(step, testRun, personName),
        runStatus: stepRunStatus(step, testRun),
      },
    })),
  ]

  const edges: Edge[] = workflow.steps.map((step, index) => {
    const sourceId = index === 0 ? 'trigger' : workflow.steps[index - 1].key
    const conditional = step.when !== undefined

    return {
      id: `${sourceId}-${step.key}`,
      source: sourceId,
      target: step.key,
      label: conditional ? describeCondition(step.when!) : undefined,
      style: conditional ? { strokeDasharray: '5 5' } : undefined,
      markerEnd: { type: MarkerType.ArrowClosed },
    }
  })

  return { nodes, edges }
}
