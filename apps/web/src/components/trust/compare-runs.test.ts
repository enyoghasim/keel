import type { EvalResult } from 'api-types'
import { describe, expect, it } from 'vitest'
import { compareRuns } from './compare-runs'

function result(caseKey: string, passed: boolean): EvalResult {
  return {
    id: Math.random(),
    eval_case_id: caseKey.length,
    case_key: caseKey,
    input: { question: `Question for ${caseKey}` },
    expected: {},
    passed,
    score: null,
    metrics: {},
    actual: null,
    diff: [],
    latency_ms: 100,
    error_message: null,
  }
}

describe('compareRuns', () => {
  it('lists only the cases that flipped between two runs, fixes and regressions separately', () => {
    const before = [result('leave', true), result('fiscal', false), result('travel', true), result('count', true)]
    const after = [result('leave', true), result('fiscal', true), result('travel', false), result('count', true)]

    const comparison = compareRuns(before, after)

    expect(comparison.fixed.map((c) => c.caseKey)).toEqual(['fiscal'])
    expect(comparison.regressed.map((c) => c.caseKey)).toEqual(['travel'])
    expect(comparison.regressed[0].question).toBe('Question for travel')
    expect(comparison.unchanged).toBe(2)
  })

  it('ignores cases that only one of the runs had', () => {
    const comparison = compareRuns([result('old', false)], [result('new', true)])

    expect(comparison).toEqual({ fixed: [], regressed: [], unchanged: 0 })
  })
})
