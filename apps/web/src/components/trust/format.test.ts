import type { EvalDiffEntry, EvalResultMetrics } from 'api-types'
import { describe, expect, it } from 'vitest'
import { describeDiffEntry, describeMetrics, formatCost } from './format'

describe('describeDiffEntry', () => {
  it('names the probe a compiled rule set got wrong, with what each side decided', () => {
    const entry: EvalDiffEntry = {
      field: 'behaviour',
      probe: { 'requester.department': 'Engineering', 'payload.amount_eur': 1000 },
      expected: 'auto_approve',
      actual: 'require_approval (manager_of(requester))',
    }

    expect(describeDiffEntry(entry)).toBe(
      'behaviour at requester.department=Engineering, payload.amount_eur=1000: expected auto_approve, got require_approval (manager_of(requester))',
    )
  })

  it('names a hallucinated quote and a missed ambiguity', () => {
    expect(describeDiffEntry({ field: 'source_quote', rule: 'conf', actual: 'Free laptops.' })).toBe('source_quote in conf: not in the passage — “Free laptops.”')
    expect(describeDiffEntry({ field: 'ambiguity', expected: 'attending conferences' })).toBe('ambiguity: missed “attending conferences”')
  })

  it('falls back to field, expected and actual for simple diffs', () => {
    expect(describeDiffEntry({ field: 'metric', expected: 'leave_days', actual: 'request_count' })).toBe('metric: expected leave_days, got request_count')
    expect(describeDiffEntry({ field: 'tools', expected: 'check_policy', actual: ['search_people'] })).toBe('tools: expected check_policy, got ["search_people"]')
  })
})

describe('describeMetrics', () => {
  it('summarises policy extraction metrics', () => {
    const metrics: EvalResultMetrics = { behaviour: 0.667, quotes_verified: 1, ambiguity_recall: 0.5, stability: 0.8667 }

    expect(describeMetrics(metrics)).toEqual(['Behaviour 66.7%', 'Quotes verified 100%', 'Ambiguity recall 50%', 'Stability 86.7%'])
  })

  it('summarises the judge and cost for an agent case', () => {
    const metrics: EvalResultMetrics = {
      judge: { correctness: 5, citation: 4, clarity: 5, no_false_claims: 5, mean: 4.75 },
      judge_agreement: 0.75,
      cost_usd: 0.0123,
    }

    expect(describeMetrics(metrics)).toEqual(['Judge 4.75 / 5', 'Judge agrees with label 75%', '$0.012'])
  })

  it('is empty for an insights case', () => {
    expect(describeMetrics({})).toEqual([])
  })
})

describe('formatCost', () => {
  it('shows three decimals under a dollar, two above, and a floor for dust', () => {
    expect(formatCost(0.006123)).toBe('$0.006')
    expect(formatCost(12.5)).toBe('$12.50')
    expect(formatCost(0.0001)).toBe('<$0.001')
  })
})
