import type { Department, Person } from 'api-types'
import { describe, expect, it } from 'vitest'
import { buildOrgGraph, departmentColorClass } from './org-graph'

function person(overrides: Partial<Person> & Pick<Person, 'id' | 'name'>): Person {
  return {
    email: `${overrides.name.toLowerCase().replace(/\s+/g, '.')}@nubo.test`,
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
