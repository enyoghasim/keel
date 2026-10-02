import type { AgentStep } from 'api-types'
import { formatCost } from '../trust/format'

// The trace footer: "4 steps · 2.1 s · 3,412 tokens · $0.006" (SPEC.md
// section 9). The cost is left off when the model had no known pricing.
export function traceTotals(steps: AgentStep[], costUsd: number | null = null) {
  const ms = steps.reduce((sum, s) => sum + (s.latency_ms ?? 0), 0)
  const tokens = steps.reduce((sum, s) => sum + (s.tokens ?? 0), 0)
  const parts = [`${steps.length} ${steps.length === 1 ? 'step' : 'steps'}`, `${(ms / 1000).toFixed(1)} s`, `${tokens.toLocaleString('en-GB')} tokens`]
  if (costUsd !== null) parts.push(formatCost(costUsd))
  return parts.join(' · ')
}
