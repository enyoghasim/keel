import type { Action, Condition } from 'api-types'
import { describe, expect, it } from 'vitest'
import { describeRule } from './describe-rule'

describe('describeRule', () => {
  it('describes an all-condition with multiple fields and an auto-approve action', () => {
    const conditions: Condition = {
      all: [
        { field: 'requester.department', op: 'eq', value: 'Engineering' },
        { field: 'payload.category', op: 'eq', value: 'conference' },
        { field: 'payload.amount_eur', op: 'lte', value: 1000 },
      ],
    }
    const actions: Action = { decision: 'auto_approve' }

    expect(describeRule(conditions, actions)).toBe(
      'If department is Engineering and category is conference and amount ≤ €1,000 → auto-approve',
    )
  })

  it('describes a bare leaf condition with no all/any wrapper', () => {
    const conditions: Condition = { field: 'payload.amount_eur', op: 'gt', value: 2000 }
    const actions: Action = { decision: 'require_approval', approvers: ['manager_of(requester)'] }

    expect(describeRule(conditions, actions)).toBe(
      "If amount > €2,000 → send to the requester's manager for approval",
    )
  })

  it('describes an any-condition joined with "or"', () => {
    const conditions: Condition = {
      any: [
        { field: 'payload.category', op: 'eq', value: 'conference' },
        { field: 'payload.category', op: 'eq', value: 'training' },
      ],
    }
    const actions: Action = { decision: 'auto_approve' }

    expect(describeRule(conditions, actions)).toBe('If category is conference or category is training → auto-approve')
  })

  it('wraps a nested any inside an all in parentheses', () => {
    const conditions: Condition = {
      all: [
        { field: 'requester.department', op: 'eq', value: 'Engineering' },
        {
          any: [
            { field: 'payload.category', op: 'eq', value: 'conference' },
            { field: 'payload.category', op: 'eq', value: 'training' },
          ],
        },
      ],
    }
    const actions: Action = { decision: 'auto_approve' }

    expect(describeRule(conditions, actions)).toBe(
      'If department is Engineering and (category is conference or category is training) → auto-approve',
    )
  })

  it('describes a between operator', () => {
    const conditions: Condition = { field: 'payload.amount_eur', op: 'between', value: [500, 1000] }
    const actions: Action = { decision: 'auto_approve' }

    expect(describeRule(conditions, actions)).toBe('If amount is between €500 and €1,000 → auto-approve')
  })

  it('describes an in operator with multiple values', () => {
    const conditions: Condition = { field: 'requester.department', op: 'in', value: ['Engineering', 'Sales'] }
    const actions: Action = { decision: 'auto_approve' }

    expect(describeRule(conditions, actions)).toBe('If department is one of Engineering, Sales → auto-approve')
  })

  it('describes a reject action with its reason', () => {
    const conditions: Condition = { field: 'payload.notice_days', op: 'lt', value: 14 }
    const actions: Action = { decision: 'reject', reason: 'insufficient notice' }

    expect(describeRule(conditions, actions)).toBe('If notice < 14 → reject (insufficient notice)')
  })

  it('describes a require_approval action with a role reference', () => {
    const conditions: Condition = { field: 'payload.amount_eur', op: 'gt', value: 2000 }
    const actions: Action = {
      decision: 'require_approval',
      approvers: ['manager_of(requester)', 'role:finance_lead'],
    }

    expect(describeRule(conditions, actions)).toBe(
      "If amount > €2,000 → send to the requester's manager, anyone with the finance_lead role for approval",
    )
  })
})
