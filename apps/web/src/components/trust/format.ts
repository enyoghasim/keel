import type { EvalDiffEntry, EvalResultMetrics } from 'api-types'

export function formatAccuracy(accuracy: number | null) {
  return accuracy === null ? '—' : `${Math.round(accuracy * 1000) / 10}%`
}

export function formatRunDate(iso: string) {
  return new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

export const SUITE_LABELS = {
  insights: 'Insights',
  policy_extraction: 'Policy extraction',
  agent: 'Agent',
} as const

export function formatCost(usd: number) {
  if (usd < 0.001) return '<$0.001'
  return `$${usd.toFixed(usd >= 1 ? 2 : 3)}`
}

function show(value: unknown) {
  return typeof value === 'string' ? value : JSON.stringify(value)
}

/** One scorer finding as a sentence a person can read in the failure drill-down. */
export function describeDiffEntry(entry: EvalDiffEntry): string {
  if (entry.probe) {
    const at = Object.entries(entry.probe)
      .map(([field, value]) => `${field}=${show(value)}`)
      .join(', ')
    return `${entry.field} at ${at}: expected ${show(entry.expected)}, got ${show(entry.actual)}`
  }
  if (entry.field === 'source_quote') return `source_quote in ${entry.rule}: not in the passage — “${show(entry.actual)}”`
  if (entry.field === 'ambiguity') return `ambiguity: missed “${show(entry.expected)}”`
  return `${entry.field}: expected ${show(entry.expected)}, got ${show(entry.actual)}`
}

/** The per-case scores beyond pass/fail, as short labels. */
export function describeMetrics(metrics: EvalResultMetrics): string[] {
  const labels: string[] = []
  if (metrics.behaviour !== undefined) labels.push(`Behaviour ${formatAccuracy(metrics.behaviour)}`)
  if (metrics.quotes_verified !== undefined) labels.push(`Quotes verified ${formatAccuracy(metrics.quotes_verified)}`)
  if (metrics.ambiguity_recall !== undefined) labels.push(`Ambiguity recall ${formatAccuracy(metrics.ambiguity_recall)}`)
  if (metrics.stability !== undefined) labels.push(`Stability ${formatAccuracy(metrics.stability)}`)
  if (metrics.judge) labels.push(`Judge ${metrics.judge.mean} / 5`)
  if (metrics.judge_agreement !== undefined) labels.push(`Judge agrees with label ${formatAccuracy(metrics.judge_agreement)}`)
  if (metrics.cost_usd !== undefined) labels.push(formatCost(metrics.cost_usd))
  return labels
}
