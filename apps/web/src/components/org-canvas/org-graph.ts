import type { Department, Person } from 'api-types'
import dagre from 'dagre'
import type { Edge, Node } from '@xyflow/react'

export interface PersonNodeData extends Record<string, unknown> {
  person: Person
  departmentName: string | null
  colorClass: string
}

export const NODE_WIDTH = 208
export const NODE_HEIGHT = 56

const DEPARTMENT_COLORS = [
  'bg-chart-1/15 border-chart-1 text-chart-1',
  'bg-chart-2/15 border-chart-2 text-chart-2',
  'bg-chart-3/15 border-chart-3 text-chart-3',
  'bg-chart-4/15 border-chart-4 text-chart-4',
  'bg-chart-5/15 border-chart-5 text-chart-5',
  'bg-chart-6/15 border-chart-6 text-chart-6',
]
const NEUTRAL_COLOR = 'bg-muted border-border-strong text-foreground'

export function departmentColorClass(index: number): string {
  if (index < 0) return NEUTRAL_COLOR
  return DEPARTMENT_COLORS[index % DEPARTMENT_COLORS.length]
}

export function buildOrgGraph(
  people: Person[],
  departments: Department[],
  options: { colorByDepartment?: boolean } = {},
): { nodes: Node<PersonNodeData>[]; edges: Edge[] } {
  const colorByDepartment = options.colorByDepartment ?? true
  const peopleIds = new Set(people.map((p) => p.id))
  const departmentById = new Map(departments.map((d) => [d.id, d]))
  const sortedDepartmentIds = [...departmentById.keys()].sort((a, b) => a - b)

  const graph = new dagre.graphlib.Graph()
  graph.setGraph({ rankdir: 'TB', nodesep: 24, ranksep: 56 })
  graph.setDefaultEdgeLabel(() => ({}))

  for (const person of people) {
    graph.setNode(String(person.id), { width: NODE_WIDTH, height: NODE_HEIGHT })
  }

  const edges: Edge[] = []
  for (const person of people) {
    const hasResolvableManager = person.manager_id !== null && peopleIds.has(person.manager_id)
    if (!hasResolvableManager) continue

    graph.setEdge(String(person.manager_id), String(person.id))
    edges.push({ id: `${person.manager_id}-${person.id}`, source: String(person.manager_id), target: String(person.id) })
  }

  dagre.layout(graph)

  const nodes: Node<PersonNodeData>[] = people.map((person) => {
    const layout = graph.node(String(person.id))
    const department = person.department_id !== null ? departmentById.get(person.department_id) : undefined
    const colorIndex =
      colorByDepartment && person.department_id !== null ? sortedDepartmentIds.indexOf(person.department_id) : -1

    return {
      id: String(person.id),
      type: 'person',
      position: { x: layout.x - NODE_WIDTH / 2, y: layout.y - NODE_HEIGHT / 2 },
      data: {
        person,
        departmentName: department?.name ?? null,
        colorClass: departmentColorClass(colorIndex),
      },
    }
  })

  return { nodes, edges }
}
