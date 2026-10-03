import type { Department, Person } from 'api-types'
import { describe, expect, it } from 'vitest'
import { buildOrgGraph, departmentColorClass, NODE_HEIGHT, NODE_WIDTH } from './org-graph'

function person(overrides: Partial<Person> & Pick<Person, 'id' | 'name'>): Person {
  return {
    email: `${overrides.name.toLowerCase().replace(/\s+/g, '.')}@factorial.test`,
    title: null,
    department_id: null,
    manager_id: null,
    location: null,
    start_date: null,
    roles: [],
    ...overrides,
  }
}

const sales: Department = { id: 10, name: 'Sales', head_id: 1 }
const ops: Department = { id: 20, name: 'Operations', head_id: 2 }

describe('buildOrgGraph', () => {
  it('creates one node per person, carrying the person and resolved department name', () => {
    const people = [person({ id: 1, name: 'Tunde Bakare', department_id: 10 })]
    const { nodes } = buildOrgGraph(people, [sales])

    expect(nodes).toHaveLength(1)
    expect(nodes[0].id).toBe('1')
    expect(nodes[0].data.person).toBe(people[0])
    expect(nodes[0].data.departmentName).toBe('Sales')
  })

  it('creates an edge from manager to report for every resolvable manager_id', () => {
    const people = [
      person({ id: 1, name: 'Tunde Bakare' }),
      person({ id: 2, name: 'Ngozi Doe', manager_id: 1 }),
    ]
    const { edges } = buildOrgGraph(people, [])

    expect(edges).toEqual([expect.objectContaining({ source: '1', target: '2' })])
  })

  it('treats a manager_id pointing outside the roster as a root instead of crashing', () => {
    const people = [person({ id: 2, name: 'Ngozi Doe', manager_id: 999 })]
    const { nodes, edges } = buildOrgGraph(people, [])

    expect(edges).toHaveLength(0)
    expect(nodes).toHaveLength(1)
  })

  it('lays out managers above their reports in a top-down tree', () => {
    const people = [
      person({ id: 1, name: 'Tunde Bakare' }),
      person({ id: 2, name: 'Ngozi Doe', manager_id: 1 }),
    ]
    const { nodes } = buildOrgGraph(people, [])

    const manager = nodes.find((n) => n.id === '1')!
    const report = nodes.find((n) => n.id === '2')!
    expect(manager.position.y).toBeLessThan(report.position.y)
  })

  it('gives every person without a department a null department name and the neutral color', () => {
    const people = [person({ id: 1, name: 'Tunde Bakare' })]
    const { nodes } = buildOrgGraph(people, [])

    expect(nodes[0].data.departmentName).toBeNull()
    expect(nodes[0].data.colorClass).toBe(departmentColorClass(-1))
  })

  it('gives everyone in the same department the same color, and different departments different colors', () => {
    const people = [
      person({ id: 1, name: 'Tunde Bakare', department_id: 10 }),
      person({ id: 2, name: 'Ngozi Doe', department_id: 10 }),
      person({ id: 3, name: 'Ada Nwosu', department_id: 20 }),
    ]
    const { nodes } = buildOrgGraph(people, [sales, ops])
    const byId = Object.fromEntries(nodes.map((n) => [n.id, n.data.colorClass]))

    expect(byId['1']).toBe(byId['2'])
    expect(byId['1']).not.toBe(byId['3'])
  })

  it('falls back every node to the neutral color when colorByDepartment is off', () => {
    const people = [person({ id: 1, name: 'Tunde Bakare', department_id: 10 })]
    const { nodes } = buildOrgGraph(people, [sales], { colorByDepartment: false })

    expect(nodes[0].data.colorClass).toBe(departmentColorClass(-1))
  })
})

describe('departmentColorClass', () => {
  it('returns the neutral color for a negative index', () => {
    expect(departmentColorClass(-1)).toMatch(/muted/)
  })

  it('cycles through the palette for indices beyond its length', () => {
    expect(departmentColorClass(0)).toBe(departmentColorClass(6))
  })
})

describe('buildOrgGraph compact layout', () => {
  // Roughly Factorial's shape: a CEO over eight department heads, each with up to a dozen individual contributors,
  // two of whom lead small teams of their own.
  function factorial(): Person[] {
    const people: Person[] = [person({ id: 1, name: 'CEO' })]
    let id = 2
    for (let head = 0; head < 8; head += 1) {
      const headId = id++
      people.push(person({ id: headId, name: `Head ${head}`, manager_id: 1 }))
      const reports = head === 0 ? 3 : 8
      for (let r = 0; r < reports; r += 1) people.push(person({ id: id++, name: `IC ${head}-${r}`, manager_id: headId }))
    }
    const lead = id++
    people.push(person({ id: lead, name: 'Team lead', manager_id: 2 }))
    for (let r = 0; r < 4; r += 1) people.push(person({ id: id++, name: `Member ${r}`, manager_id: lead }))
    return people
  }

  const boxes = (nodes: ReturnType<typeof buildOrgGraph>['nodes']) =>
    nodes.map((n) => ({ id: n.id, left: n.position.x, top: n.position.y, right: n.position.x + NODE_WIDTH, bottom: n.position.y + NODE_HEIGHT }))

  it('stacks a manager\'s reports with no reports of their own in one column beneath them', () => {
    const people = [
      person({ id: 1, name: 'Amaka Obi' }),
      person({ id: 2, name: 'Ada', manager_id: 1 }),
      person({ id: 3, name: 'Bisi', manager_id: 1 }),
      person({ id: 4, name: 'Chidi', manager_id: 1 }),
    ]
    const { nodes, edges } = buildOrgGraph(people, [])
    const reports = ['2', '3', '4'].map((id) => nodes.find((n) => n.id === id)!)

    expect(new Set(reports.map((n) => n.position.x)).size).toBe(1)
    expect(reports[0].position.y).toBeGreaterThan(nodes.find((n) => n.id === '1')!.position.y)
    expect(reports[1].position.y).toBeGreaterThanOrEqual(reports[0].position.y + NODE_HEIGHT)
    expect(reports[2].position.y).toBeGreaterThanOrEqual(reports[1].position.y + NODE_HEIGHT)
    // each hangs off a spine into its left side
    expect(edges.every((e) => e.type === 'spine' && e.targetHandle === 'left')).toBe(true)
  })

  it('keeps a report who leads a team in the tree row beside the stacked column, with ordinary edges', () => {
    const people = [
      person({ id: 1, name: 'Head' }),
      person({ id: 2, name: 'Solo', manager_id: 1 }),
      person({ id: 3, name: 'Lead', manager_id: 1 }),
      person({ id: 4, name: 'Member', manager_id: 3 }),
    ]
    const { nodes, edges } = buildOrgGraph(people, [])
    const solo = nodes.find((n) => n.id === '2')!
    const lead = nodes.find((n) => n.id === '3')!

    expect(lead.position.x).toBeGreaterThan(solo.position.x)
    expect(lead.position.y).toBe(solo.position.y)
    expect(edges.find((e) => e.target === '3')!.type).toBeUndefined()
    expect(edges.find((e) => e.target === '4')!.type).toBe('spine')
  })

  it('never overlaps two people, in a company the size of Factorial', () => {
    const placed = boxes(buildOrgGraph(factorial(), []).nodes)

    for (const [i, a] of placed.entries()) {
      for (const b of placed.slice(i + 1)) {
        const apart = a.right <= b.left || b.right <= a.left || a.bottom <= b.top || b.bottom <= a.top
        expect(apart, `${a.id} overlaps ${b.id}`).toBe(true)
      }
    }
  })

  it('is closer to a page than to one very wide row, in a company the size of Factorial', () => {
    const placed = boxes(buildOrgGraph(factorial(), []).nodes)
    const width = Math.max(...placed.map((b) => b.right)) - Math.min(...placed.map((b) => b.left))
    const height = Math.max(...placed.map((b) => b.bottom)) - Math.min(...placed.map((b) => b.top))

    // One row of these 78 people was ~18,000px wide and 56px tall (a ratio over 300).
    expect(width / height).toBeLessThan(4)
    expect(width).toBeLessThan(3000)
  })

  it('wraps a manager\'s many team leads onto further rows instead of one endless line', () => {
    const people: Person[] = [person({ id: 1, name: 'Director' })]
    for (let i = 0; i < 12; i += 1) {
      people.push(person({ id: 10 + i, name: `Lead ${i}`, manager_id: 1 }), person({ id: 100 + i, name: `Member ${i}`, manager_id: 10 + i }))
    }
    const { nodes } = buildOrgGraph(people, [])
    const leadTops = new Set(nodes.filter((n) => Number(n.id) >= 10 && Number(n.id) < 100).map((n) => n.position.y))
    const right = Math.max(...nodes.map((n) => n.position.x + NODE_WIDTH))

    expect(leadTops.size).toBeGreaterThan(1)
    expect(right).toBeLessThan(2000)
  })
})
