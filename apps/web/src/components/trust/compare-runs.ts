import type { EvalResult } from 'api-types'

export interface FlippedCase {
  caseKey: string
  question: string
}

export interface RunComparison {
  fixed: FlippedCase[]
  regressed: FlippedCase[]
  unchanged: number
}

// What a case asked, whichever suite it belongs to: an insights question, an
// agent message, or the start of a handbook passage.
export function caseQuestion(result: EvalResult) {
  const { question, message, passage } = result.input
  if (typeof question === 'string') return question
  if (typeof message === 'string') return message
  if (typeof passage === 'string') return passage.length > 90 ? `${passage.slice(0, 90)}…` : passage
  return result.case_key
}

/**
 * SPEC.md section 12's side-by-side comparison: which cases flipped
 * between two runs of the same suite. Cases only one run had (added or
 * archived between runs) can't have flipped, so they're left out.
 */
export function compareRuns(before: EvalResult[], after: EvalResult[]): RunComparison {
  const beforeByKey = new Map(before.map((r) => [r.case_key, r]))
  const comparison: RunComparison = { fixed: [], regressed: [], unchanged: 0 }

  for (const afterResult of after) {
    const beforeResult = beforeByKey.get(afterResult.case_key)
    if (!beforeResult) continue

    const flipped = { caseKey: afterResult.case_key, question: caseQuestion(afterResult) }
    if (!beforeResult.passed && afterResult.passed) comparison.fixed.push(flipped)
    else if (beforeResult.passed && !afterResult.passed) comparison.regressed.push(flipped)
    else comparison.unchanged += 1
  }

  return comparison
}
