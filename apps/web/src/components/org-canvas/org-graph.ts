import type { Department, Person } from 'api-types'
import type { Edge, Node } from '@xyflow/react'

export interface PersonNodeData extends Record<string, unknown> {
  person: Person
  departmentName: string | null
  colorClass: string
}

export const NODE_WIDTH = 208
export const NODE_HEIGHT = 56

// Layout spacing. Reports with nobody under them are stacked in a column hung
// off a spine, so a department head with a dozen people is tall, not wide.
const SIBLING_GAP = 24
const RANK_GAP = 40
const STACK_GAP = 12
const SPINE_INDENT = 28
// A manager's reports wrap onto another row beyond this width, so a large department list doesn't run off as one line.
const MAX_ROW_WIDTH = 1500

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

interface Placed {
  id: string
  x: number
  y: number
}

interface Block {
  width: number
  height: number
  /** Positions relative to the block's top-left. */
  placed: Placed[]
  /** Centre of the manager's own card, relative to the block's left. */
  anchorX: number
}

const rowWidth = (row: Block[]) => row.reduce((sum, slot) => sum + slot.width, 0) + SIBLING_GAP * Math.max(0, row.length - 1)

function wrapRows(slots: Block[]): Block[][] {
  const rows: Block[][] = []
  for (const slot of slots) {
    const last = rows[rows.length - 1]
    if (last && rowWidth([...last, slot]) <= MAX_ROW_WIDTH) last.push(slot)
    else rows.push([slot])
  }
  return rows
}

/**
 * A top-down tree where each manager's reports who lead no one are stacked in
 * one column beneath them (the spine edge type draws their connectors), and
 * reports who lead teams sit side by side in a row beside that column. 78
 * people therefore lay out as roughly a page, not one very wide row.
 */
function layoutTree(people: Person[], peopleIds: Set<number>): Placed[] {
  const children = new Map<number, Person[]>()
  const roots: Person[] = []
  for (const person of people) {
    if (person.manager_id !== null && peopleIds.has(person.manager_id)) {
      children.set(person.manager_id, [...(children.get(person.manager_id) ?? []), person])
    } else {
      roots.push(person)
    }
  }

  const seen = new Set<number>()
  const layout = (person: Person): Block => {
    seen.add(person.id)
    const reports = (children.get(person.id) ?? []).filter((c) => !seen.has(c.id))
    const stacked = reports.filter((c) => !children.get(c.id)?.length)
    const leaders = reports.filter((c) => children.get(c.id)?.length)

    const slots: Block[] = []
    if (stacked.length > 0) {
      slots.push({
        width: SPINE_INDENT + NODE_WIDTH,
        height: stacked.length * (NODE_HEIGHT + STACK_GAP) - STACK_GAP,
        placed: stacked.map((c, i) => {
          seen.add(c.id)
          return { id: String(c.id), x: SPINE_INDENT, y: i * (NODE_HEIGHT + STACK_GAP) }
        }),
        anchorX: SPINE_INDENT + NODE_WIDTH / 2,
      })
    }
    for (const leader of leaders) {
      if (!seen.has(leader.id)) slots.push(layout(leader))
    }

    const rows = wrapRows(slots)
    const rowWidths = rows.map((row) => rowWidth(row))
    const width = Math.max(NODE_WIDTH, ...rowWidths)

    const placed: Placed[] = []
    let top = NODE_HEIGHT + RANK_GAP
    rows.forEach((row, index) => {
      let cursor = (width - rowWidths[index]) / 2
      for (const slot of row) {
        for (const item of slot.placed) placed.push({ id: item.id, x: cursor + item.x, y: top + item.y })
        cursor += slot.width + SIBLING_GAP
      }
      top += Math.max(...row.map((s) => s.height)) + RANK_GAP
    })

    // The manager sits centred over the widest row; with nobody beneath, it is the whole block.
    placed.push({ id: String(person.id), x: (width - NODE_WIDTH) / 2, y: 0 })
    const height = rows.length === 0 ? NODE_HEIGHT : top - RANK_GAP
    return { width, height, placed, anchorX: width / 2 }
  }

  const rootBlocks = roots.map(layout)
  // A cycle of managers has no root; lay each unreached person out as one.
  for (const person of people) if (!seen.has(person.id)) rootBlocks.push(layout(person))

  const result: Placed[] = []
  let cursor = 0
  for (const block of rootBlocks) {
    for (const item of block.placed) result.push({ id: item.id, x: cursor + item.x, y: item.y })
    cursor += block.width + SIBLING_GAP * 2
  }
  return result
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

  const positions = new Map(layoutTree(people, peopleIds).map((p) => [p.id, p]))
  const leadsSomeone = new Set(people.flatMap((p) => (p.manager_id !== null && peopleIds.has(p.manager_id) ? [p.manager_id] : [])))

  const edges: Edge[] = []
  for (const person of people) {
    const hasResolvableManager = person.manager_id !== null && peopleIds.has(person.manager_id)
    if (!hasResolvableManager) continue

    const stacked = !leadsSomeone.has(person.id)
    edges.push({
      id: `${person.manager_id}-${person.id}`,
      source: String(person.manager_id),
      target: String(person.id),
      ...(stacked ? { type: 'spine', targetHandle: 'left' } : {}),
    })
  }

  const nodes: Node<PersonNodeData>[] = people.map((person) => {
    const position = positions.get(String(person.id))!
    const department = person.department_id !== null ? departmentById.get(person.department_id) : undefined
    const colorIndex =
      colorByDepartment && person.department_id !== null ? sortedDepartmentIds.indexOf(person.department_id) : -1

    return {
      id: String(person.id),
      type: 'person',
      position: { x: position.x, y: position.y },
      // Known up front, so the first fit-view has real bounds instead of waiting on measurement.
      width: NODE_WIDTH,
      height: NODE_HEIGHT,
      data: {
        person,
        departmentName: department?.name ?? null,
        colorClass: departmentColorClass(colorIndex),
      },
    }
  })

  return { nodes, edges }
}
