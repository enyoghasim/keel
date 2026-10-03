import type { Workflow, WorkflowStep, WorkflowStepType, WorkflowTestRunStep } from 'api-types'
import { MarkerType, type Edge, type Node } from '@xyflow/react'
import { describeCondition } from '../policies/describe-rule'

export const NODE_WIDTH = 240
export const NODE_HEIGHT = 80
const X_GAP = 120

export type StepDiffStatus = 'added' | 'removed' | 'changed'

export type FlowNodeKind = 'trigger' | WorkflowStepType

export interface FlowNodeData extends Record<string, unknown> {
  kind: FlowNodeKind
  label: string
  subtitle: string | null
  /** True when `subtitle` is one real resolved person's name (a test run), not a role/org reference. */
  resolvedPerson: boolean
  /** From a test run: present once that step has been previewed, absent before any run. */
  runStatus: 'matched' | 'skipped' | null
  /** From a workflow proposal: how the step differs from the current workflow. */
  diffStatus: StepDiffStatus | null
}

// Tints each step's connecting edge to match what it leads into — approval
// blue, task green, notify brand teal — so the canvas reads by colour, not
// just by icon. Edges are keyed by the step they point AT, so trigger (never
// a target) needs no entry.
const EDGE_COLOR: Record<WorkflowStepType, string> = {
  approval: 'var(--info)',
  task: 'var(--success)',
  notify: 'var(--brand)',
}

/**
 * One step list for drawing a proposal (SPEC.md section 8): the proposed
 * steps, plus every step the change removes put back where it used to be,
 * with each step's status — added, removed, or changed in place.
 */
export function mergeWorkflowSteps(
  before: WorkflowStep[],
  after: WorkflowStep[],
): { steps: WorkflowStep[]; status: Record<string, StepDiffStatus> } {
  const beforeByKey = new Map(before.map((step) => [step.key, step]))
  const afterKeys = new Set(after.map((step) => step.key))
  const status: Record<string, StepDiffStatus> = {}
  const steps = [...after]

  for (const step of after) {
    const previous = beforeByKey.get(step.key)
    if (!previous) status[step.key] = 'added'
    else if (JSON.stringify(previous) !== JSON.stringify(step)) status[step.key] = 'changed'
  }

  before.forEach((step, index) => {
    if (afterKeys.has(step.key)) return
    status[step.key] = 'removed'
    // After the nearest earlier step that is still drawn, else at the front.
    const anchor = before.slice(0, index).reverse().find((earlier) => steps.some((s) => s.key === earlier.key))
    steps.splice(anchor ? steps.findIndex((s) => s.key === anchor.key) + 1 : 0, 0, step)
  })

  return { steps, status }
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

function stepSubtitle(
  step: WorkflowStep,
  testRunSteps: WorkflowTestRunStep[] | null,
  personName: (id: number) => string,
): { text: string | null; resolvedPerson: boolean } {
  if (testRunSteps !== null) {
    const resolved = testRunSteps.filter((s) => s.step_key === step.key && s.resolved_person_id !== null)
    if (resolved.length === 1) return { text: personName(resolved[0].resolved_person_id as number), resolvedPerson: true }
    if (resolved.length > 1) return { text: resolved.map((s) => personName(s.resolved_person_id as number)).join(', '), resolvedPerson: false }
  }

  if (step.type === 'approval') return { text: null, resolvedPerson: false }
  return { text: step.assignee ?? null, resolvedPerson: false }
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
  diffStatus: Record<string, StepDiffStatus> = {},
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
        resolvedPerson: false,
        runStatus: triggerRunStatus,
        diffStatus: null,
      },
    },
    ...workflow.steps.map((step, index) => {
      const subtitle = stepSubtitle(step, testRun, personName)
      return {
        id: step.key,
        type: 'flowStep',
        position: { x: (index + 1) * (NODE_WIDTH + X_GAP), y: 0 },
        data: {
          kind: step.type,
          label: step.title ?? step.key,
          subtitle: subtitle.text,
          resolvedPerson: subtitle.resolvedPerson,
          runStatus: stepRunStatus(step, testRun),
          diffStatus: diffStatus[step.key] ?? null,
        },
      }
    }),
  ]

  const edges: Edge[] = workflow.steps.map((step, index) => {
    const sourceId = index === 0 ? 'trigger' : workflow.steps[index - 1].key
    const conditional = step.when !== undefined
    const color = EDGE_COLOR[step.type]

    return {
      id: `${sourceId}-${step.key}`,
      source: sourceId,
      target: step.key,
      type: 'smoothstep',
      pathOptions: { borderRadius: 16 },
      label: conditional ? describeCondition(step.when!) : undefined,
      labelBgPadding: [6, 3],
      labelBgBorderRadius: 5,
      labelBgStyle: { fill: 'var(--card)', stroke: 'var(--border)', strokeWidth: 1 },
      labelStyle: { fontSize: 11, fill: 'var(--muted-foreground)', fontWeight: 500 },
      style: { stroke: color, strokeWidth: 1.75, opacity: 0.6, ...(conditional ? { strokeDasharray: '5 5' } : {}) },
      markerEnd: { type: MarkerType.ArrowClosed, color, width: 18, height: 18 },
    }
  })

  return { nodes, edges }
}
