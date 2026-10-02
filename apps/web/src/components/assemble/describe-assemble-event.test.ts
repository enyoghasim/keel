import { describe, expect, it } from 'vitest'
import { describeAssembleEvent } from './describe-assemble-event'

describe('describeAssembleEvent', () => {
  it('describes a mapping_complete event by its column count', () => {
    expect(
      describeAssembleEvent({
        stage: 'csv',
        event: 'mapping_complete',
        data: { mappings: [{ column: 'Full Name' }, { column: 'E-mail' }] },
        progress: 0.1,
      }),
    ).toBe('Mapped 2 columns')
  })

  it('describes a person_added event with their department', () => {
    expect(
      describeAssembleEvent({
        stage: 'graph',
        event: 'person_added',
        data: { id: 1, name: 'Ngozi Eze', manager_id: 17, department: 'Sales' },
        progress: 0.3,
      }),
    ).toBe('Ngozi Eze added to Sales')
  })

  it('describes a person_added event with no department', () => {
    expect(
      describeAssembleEvent({
        stage: 'graph',
        event: 'person_added',
        data: { id: 1, name: 'Ngozi Eze', manager_id: null, department: null },
        progress: 0.3,
      }),
    ).toBe('Ngozi Eze added')
  })

  it('describes a chunks_embedded event by its chunk count', () => {
    expect(
      describeAssembleEvent({ stage: 'handbook', event: 'chunks_embedded', data: { count: 42 }, progress: 0.5 }),
    ).toBe('Embedded 42 handbook chunks')
  })

  it('describes a rule_extracted event by its category', () => {
    expect(
      describeAssembleEvent({
        stage: 'policies',
        event: 'rule_extracted',
        data: { id: 9, key: 'leave_under_5_days', policy_id: 3, category: 'leave' },
        progress: 0.6,
      }),
    ).toBe('Extracted rule "leave_under_5_days" (leave)')
  })

  it('describes a workflow_generated event by its request kind', () => {
    expect(
      describeAssembleEvent({
        stage: 'workflows',
        event: 'workflow_generated',
        data: { id: 2, request_kind: 'expense' },
        progress: 1,
      }),
    ).toBe('Generated the expense workflow')
  })
})
