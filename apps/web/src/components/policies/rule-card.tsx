import type { Rule, RuleStatus } from 'api-types'
import { useState } from 'react'
import { AmbiguityBanner } from './ambiguity-banner'
import { describeRule } from './describe-rule'

const STATUS_LABEL: Record<RuleStatus, string> = {
  extracted: 'Extracted',
  resolved: 'Resolved',
  active: 'Active',
  superseded: 'Superseded',
}

const STATUS_TONE: Record<RuleStatus, string> = {
  extracted: 'border-border-strong bg-secondary text-muted-foreground',
  resolved: 'border-info/40 bg-info-muted text-info',
  active: 'border-success/40 bg-success-muted text-success',
  superseded: 'border-border-strong bg-secondary text-subtle-foreground',
}

export function RuleCard({
  rule,
  matched,
  onHover,
}: {
  rule: Rule
  matched: boolean
  onHover: (ruleId: number | null) => void
}) {
  const [showJson, setShowJson] = useState(false)

  return (
    <div
      onMouseEnter={() => onHover(rule.id)}
      onMouseLeave={() => onHover(null)}
      className={`rounded-lg border px-4 py-3 transition-colors ${
        matched ? 'border-info bg-info-muted' : 'border-border bg-card'
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <p className="text-[13px]">{describeRule(rule.conditions, rule.actions)}</p>
        <span className={`shrink-0 rounded border px-1.5 py-0.5 text-[11px] font-medium ${STATUS_TONE[rule.status]}`}>
          {STATUS_LABEL[rule.status]}
        </span>
      </div>

      <div className="mt-2 flex items-center gap-3 text-[12px] text-muted-foreground">
        <span>Priority {rule.priority}</span>
        <button type="button" onClick={() => setShowJson((value) => !value)} className="underline">
          {showJson ? 'Hide JSON' : 'Show JSON'}
        </button>
      </div>

      {showJson && (
        <pre className="mt-2 overflow-x-auto rounded bg-secondary p-2 text-[11px] font-mono">
          {JSON.stringify({ conditions: rule.conditions, actions: rule.actions }, null, 2)}
        </pre>
      )}

      {rule.ambiguities.length > 0 && (
        <div className="mt-2.5 space-y-2">
          {rule.ambiguities.map((ambiguity, index) => (
            <AmbiguityBanner key={index} ambiguity={ambiguity} />
          ))}
        </div>
      )}
    </div>
  )
}
