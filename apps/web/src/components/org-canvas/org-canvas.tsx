import { Background, Controls, ReactFlow } from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import type { Department, Person } from 'api-types'
import { useMemo } from 'react'
import { buildOrgGraph } from './org-graph'
import { PersonNode } from './person-node'

const nodeTypes = { person: PersonNode }

/**
 * Shared org-chart canvas: a top-down tree of `people`, grouped visually by
 * `departments`, laid out with dagre. Used by /graph today; /assemble will
 * reuse it once its "growing during assembly" animation is built.
 */
export function OrgCanvas({
  people,
  departments,
  colorByDepartment = true,
  selectedPersonId = null,
  onSelectPerson,
}: {
  people: Person[]
  departments: Department[]
  colorByDepartment?: boolean
  selectedPersonId?: number | null
  onSelectPerson?: (personId: number) => void
}) {
  const { nodes, edges } = useMemo(
    () => buildOrgGraph(people, departments, { colorByDepartment }),
    [people, departments, colorByDepartment],
  )

  const styledNodes = useMemo(
    () => nodes.map((node) => ({ ...node, selected: node.id === String(selectedPersonId) })),
    [nodes, selectedPersonId],
  )

  return (
    <div className="h-150 rounded-lg border border-border bg-card">
      <ReactFlow
        nodes={styledNodes}
        edges={edges}
        nodeTypes={nodeTypes}
        onNodeClick={(_event, node) => onSelectPerson?.(Number(node.id))}
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
