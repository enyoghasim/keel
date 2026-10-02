import type { Department, Person } from 'api-types'
import { describe, expect, it } from 'vitest'
import { describeDiffOp } from './describe-diff-op'

const people = new Map<number, Person>([
  [1, { id: 1, name: 'Tunde Bakare', email: '', title: null, department_id: null, manager_id: null, location: null, start_date: null, roles: [] }],
  [2, { id: 2, name: 'Ada Nwosu', email: '', title: null, department_id: null, manager_id: null, location: null, start_date: null, roles: [] }],
])

const departments = new Map<number, Department>([[10, { id: 10, name: 'Sales', head_id: null }]])

describe('describeDiffOp', () => {
  it('describes a manager change with the previous manager named', () => {
    expect(describeDiffOp({ op: 'change_manager', person_id: 3, from: 1, to: 2 }, people, departments)).toBe(
      'Person #3 now reports to Ada Nwosu instead of Tunde Bakare',
    )
  })

  it('describes a manager change with no previous manager on record', () => {
    expect(describeDiffOp({ op: 'change_manager', person_id: 3, to: 2 }, people, departments)).toBe(
      'Person #3 now reports to Ada Nwosu',
    )
  })

  it('describes a department head change', () => {
    expect(describeDiffOp({ op: 'set_department_head', department_id: 10, to: 2 }, people, departments)).toBe(
      "Sales's head becomes Ada Nwosu",
    )
  })

  it('describes clearing a department head as "nobody"', () => {
    expect(describeDiffOp({ op: 'set_department_head', department_id: 10, to: null }, people, departments)).toBe(
      "Sales's head becomes nobody",
    )
  })

  it('describes a role assignment', () => {
    expect(describeDiffOp({ op: 'assign_role', person_id: 1, role: 'finance_lead' }, people, departments)).toBe(
      'Tunde Bakare is assigned the role "finance_lead"',
    )
  })

  it('falls back to a numbered label when a person is not in the lookup', () => {
    expect(describeDiffOp({ op: 'assign_role', person_id: 99, role: 'finance_lead' }, people, departments)).toBe(
      'Person #99 is assigned the role "finance_lead"',
    )
  })
})
