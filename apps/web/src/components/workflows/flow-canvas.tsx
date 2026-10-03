import { Background, BackgroundVariant, Controls, ReactFlow } from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import type { Person, Workflow, WorkflowTestRunStep } from 'api-types'
import { useMemo } from 'react'
import { buildFlowGraph, NODE_HEIGHT, type StepDiffStatus } from './flow-graph'
import { FlowStepNode } from './flow-step-node'

const nodeTypes = { flowStep: FlowStepNode }

// Matches the canvas's fixed height (h-104 = 26rem = 416px) below. A long
// chain of steps is meant to be panned, not shrunk to fit — nodes stay a
// constant, readable size regardless of how many steps a workflow has, the
// same way n8n never rescales a node to squeeze a long flow on screen.
// Keeping the viewport fixed (rather than fitView) also means it always
// starts left-aligned on the trigger, instead of centred on whatever the
// chain's midpoint happens to be.
const CANVAS_HEIGHT = 416
const DEFAULT_ZOOM = 0.85
const DEFAULT_VIEWPORT = { x: 28, y: CANVAS_HEIGHT / 2 - (NODE_HEIGHT / 2) * DEFAULT_ZOOM, zoom: DEFAULT_ZOOM }

/**
 * Shared left-to-right step graph for a workflow (SPEC.md section 8): a
 * trigger node, then one node per step, coloured by type. Pass `testRun`
 * once a test run has resolved to light up matched steps with the person
 * each one resolved to, and grey out any step whose `when` didn't fire.
 */
export function FlowCanvas({
  workflow,
  people,
  testRun = null,
  diffStatus,
}: {
  workflow: Workflow
  people: Person[]
  testRun?: WorkflowTestRunStep[] | null
  /** Outlines added/removed/changed steps, for drawing a proposal. */
  diffStatus?: Record<string, StepDiffStatus>
}) {
  const personName = useMemo(() => {
    const byId = new Map(people.map((p) => [p.id, p.name]))
    return (id: number) => byId.get(id) ?? `Person #${id}`
  }, [people])

  const { nodes, edges } = useMemo(() => buildFlowGraph(workflow, testRun, personName, diffStatus), [workflow, testRun, personName, diffStatus])

  return (
    <div className="h-104 overflow-hidden rounded-lg border border-border bg-secondary">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        nodesDraggable={false}
        nodesConnectable={false}
        defaultViewport={DEFAULT_VIEWPORT}
        minZoom={0.4}
        maxZoom={1.5}
        proOptions={{ hideAttribution: true }}
      >
        <Background variant={BackgroundVariant.Dots} gap={22} size={2} color="var(--border-strong)" className="opacity-70" />
        <Controls showInteractive={false} className="[&>button]:border-border! [&>button]:bg-card! [&>button]:fill-foreground!" />
      </ReactFlow>
    </div>
  )
}
