import type { AgentStep } from 'api-types'

// The trace footer: "4 steps · 2.1 s · 3,412 tokens" (SPEC.md section 9).
export function traceTotals(steps: AgentStep[]) {
  const ms = steps.reduce((sum, s) => sum + (s.latency_ms ?? 0), 0)
  const tokens = steps.reduce((sum, s) => sum + (s.tokens ?? 0), 0)
  return `${steps.length} ${steps.length === 1 ? 'step' : 'steps'} · ${(ms / 1000).toFixed(1)} s · ${tokens.toLocaleString('en-GB')} tokens`
}
