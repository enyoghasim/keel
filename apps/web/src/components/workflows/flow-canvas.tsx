import { Background, Controls, ReactFlow } from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import type { Person, Workflow, WorkflowTestRunStep } from 'api-types'
import { useMemo } from 'react'
import { buildFlowGraph, type StepDiffStatus } from './flow-graph'
import { FlowStepNode } from './flow-step-node'

const nodeTypes = { flowStep: FlowStepNode }

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
    <div className="h-80 rounded-lg border border-border bg-card">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        nodesDraggable={false}
        nodesConnectable={false}
        fitView
        proOptions={{ hideAttribution: true }}
      >
        <Background />
        <Controls showInteractive={false} />
      </ReactFlow>
    </div>
  )
}
