import { Background, Controls, ReactFlow } from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import type { Department, Person } from 'api-types'
import { useEffect, useMemo, useRef } from 'react'
import { buildOrgGraph } from './org-graph'
import { PersonNode } from './person-node'
import { SpineEdge } from './spine-edge'

const nodeTypes = { person: PersonNode }
const edgeTypes = { spine: SpineEdge }

/**
 * Shared org-chart canvas: a top-down tree of `people`, grouped visually by
 * `departments`, laid out by buildOrgGraph (stacked columns for reports who lead no one). Used by /graph today; /assemble will
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

  // The chart's box changes size after the first fit (a side panel appears, the
  // window resizes), which would leave it cropped: fit again whenever it does.
  const container = useRef<HTMLDivElement>(null)
  const flow = useRef<{ fitView: (options?: { padding?: number }) => unknown } | null>(null)
  useEffect(() => {
    if (!container.current || typeof ResizeObserver === 'undefined') return
    const observer = new ResizeObserver(() => void flow.current?.fitView({ padding: 0.05 }))
    observer.observe(container.current)
    return () => observer.disconnect()
  }, [])

  return (
    <div ref={container} className="h-150 rounded-lg border border-border bg-card">
      <ReactFlow
        nodes={styledNodes}
        edges={edges}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        onNodeClick={(_event, node) => onSelectPerson?.(Number(node.id))}
        nodesDraggable={false}
        nodesConnectable={false}
        fitView
        fitViewOptions={{ padding: 0.05 }}
        minZoom={0.05}
        onInit={(instance) => {
          flow.current = instance
        }}
        proOptions={{ hideAttribution: true }}
      >
        <Background />
        <Controls showInteractive={false} />
      </ReactFlow>
    </div>
  )
}
