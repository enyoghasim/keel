import { describe, expect, it } from 'vitest'
import type { AssembleEvent } from './assemble-event'
import { importIssues, isComplete, lowConfidenceMappings, STAGES, stageStatus, summarize } from './stage-progress'

function event(partial: Partial<AssembleEvent> & Pick<AssembleEvent, 'stage' | 'event' | 'progress'>): AssembleEvent {
  return { data: {}, ...partial }
}

describe('stageStatus', () => {
  it('is pending for every stage before any event has arrived', () => {
    for (const stage of STAGES) {
      expect(stageStatus(stage, [])).toBe('pending')
    }
  })

  it('is active for the stage the latest event belongs to, mid-stage', () => {
    const events = [event({ stage: 'graph', event: 'person_added', progress: 0.25 })]
    expect(stageStatus(STAGES.find((s) => s.key === 'graph')!, events)).toBe('active')
  })

  it('is done for stages before the latest event, and pending for stages after it', () => {
    const events = [event({ stage: 'policies', event: 'rule_extracted', progress: 0.6 })]
    expect(stageStatus(STAGES.find((s) => s.key === 'csv')!, events)).toBe('done')
    expect(stageStatus(STAGES.find((s) => s.key === 'graph')!, events)).toBe('done')
    expect(stageStatus(STAGES.find((s) => s.key === 'workflows')!, events)).toBe('pending')
  })

  it('is done for the current stage once its progress reaches that stage\'s ceiling', () => {
    const events = [event({ stage: 'csv', event: 'mapping_complete', progress: 0.1 })]
    expect(stageStatus(STAGES.find((s) => s.key === 'csv')!, events)).toBe('done')
  })
})

describe('isComplete', () => {
  it('is false with no events', () => {
    expect(isComplete([])).toBe(false)
  })

  it('is false while progress is under 1', () => {
    expect(isComplete([event({ stage: 'workflows', event: 'workflow_generated', progress: 0.9 })])).toBe(false)
  })

  it('is true once the latest event reaches progress 1', () => {
    expect(isComplete([event({ stage: 'workflows', event: 'workflow_generated', progress: 1 })])).toBe(true)
  })
})

describe('summarize', () => {
  it('counts people, departments, policies, rules and workflows from the event log', () => {
    const events: AssembleEvent[] = [
      event({ stage: 'graph', event: 'person_added', progress: 0.2, data: { name: 'Ada', department: 'Sales' } }),
      event({ stage: 'graph', event: 'person_added', progress: 0.3, data: { name: 'Tunde', department: 'Sales' } }),
      event({
        stage: 'graph',
        event: 'person_added',
        progress: 0.4,
        data: { name: 'Ngozi', department: 'Ops' },
      }),
      event({
        stage: 'policies',
        event: 'rule_extracted',
        progress: 0.6,
        data: { key: 'r1', policy_id: 1, category: 'leave' },
      }),
      event({
        stage: 'policies',
        event: 'rule_extracted',
        progress: 0.7,
        data: { key: 'r2', policy_id: 1, category: 'leave' },
      }),
      event({
        stage: 'policies',
        event: 'rule_extracted',
        progress: 0.75,
        data: { key: 'r3', policy_id: 2, category: 'expense' },
      }),
      event({ stage: 'workflows', event: 'workflow_generated', progress: 0.9, data: { request_kind: 'leave' } }),
    ]

    expect(summarize(events)).toMatchObject({ people: 3, departments: 2, policies: 2, rules: 3, workflows: 1 })
  })
})

describe('what a person has to look at', () => {
  const mapping = event({
    stage: 'csv',
    event: 'mapping_complete',
    progress: 0.1,
    data: {
      mappings: [
        { source_column: 'Full Name', field: 'name', confidence: 0.98 },
        { source_column: 'Grp', field: 'department', confidence: 0.55 },
      ],
    },
  })

  it('lists only the columns mapped with low confidence', () => {
    expect(lowConfidenceMappings([mapping])).toEqual([{ source_column: 'Grp', field: 'department', confidence: 0.55 }])
  })

  it('lists import issues in the order they arrived', () => {
    const issue = event({
      stage: 'graph',
      event: 'import_issue',
      progress: 0.4,
      data: { id: 1, row_number: 78, field: 'manager', raw_value: 'Chidi Unknownson', message: 'could not match' },
    })
    expect(importIssues([mapping, issue]).map((i) => i.row_number)).toEqual([78])
  })

  it('counts rules that need input and rules that were dropped in the summary', () => {
    const events = [
      event({ stage: 'policies', event: 'rule_extracted', progress: 0.6, data: { policy_id: 1, needs_input: true } }),
      event({ stage: 'policies', event: 'rule_extracted', progress: 0.6, data: { policy_id: 1, needs_input: false } }),
      event({ stage: 'policies', event: 'rule_rejected', progress: 0.6, data: { key: 'x' } }),
    ]
    expect(summarize(events)).toMatchObject({ rules: 2, needInput: 1, dropped: 1 })
  })
})
