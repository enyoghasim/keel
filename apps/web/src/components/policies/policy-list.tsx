import type { Policy, PolicyStatus } from 'api-types'

const STATUS_LABEL: Record<PolicyStatus, string> = {
  draft: 'Draft',
  active: 'Active',
  needs_review: 'Needs review',
  superseded: 'Superseded',
}

const STATUS_TONE: Record<PolicyStatus, string> = {
  draft: 'border-border-strong bg-secondary text-muted-foreground',
  active: 'border-success/40 bg-success-muted text-success',
  needs_review: 'border-warning/40 bg-warning-muted text-warning',
  superseded: 'border-border-strong bg-secondary text-subtle-foreground',
}

export function PolicyList({
  policies,
  activePolicyId,
  onSelect,
}: {
  policies: Policy[]
  activePolicyId: number
  onSelect: (policyId: number) => void
}) {
  return (
    <div className="flex flex-wrap gap-2" role="tablist" aria-label="Policies">
      {policies.map((policy) => {
        const active = policy.id === activePolicyId
        return (
          <button
            key={policy.id}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onSelect(policy.id)}
            className={`flex items-center gap-2 rounded-lg border px-3 py-1.5 text-[13px] font-medium ${
              active ? 'border-primary bg-primary text-primary-foreground' : 'border-border bg-card hover:bg-secondary'
            }`}
          >
            {policy.title}
            <span
              className={`rounded border px-1.5 py-0.5 text-[11px] font-medium ${
                active ? 'border-primary-foreground/30' : STATUS_TONE[policy.status]
              }`}
            >
              {STATUS_LABEL[policy.status]}
            </span>
          </button>
        )
      })}
    </div>
  )
}
