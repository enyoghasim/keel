import type { ChangeProposal, Department, Person } from 'api-types'
import { useState } from 'react'
import { ApproveRejectBar } from './approve-reject-bar'
import { ImpactSummaryCards } from './impact-summary-cards'
import { ProposalDiff } from './proposal-diff'

function Count({ label, value, danger }: { label: string; value: number; danger?: boolean }) {
  return (
    <span className={danger && value > 0 ? 'text-destructive' : 'text-muted-foreground'}>
      {value} {label}
    </span>
  )
}

const KIND_LABEL: Record<ChangeProposal['kind'], string> = {
  org: 'Org change',
  rule: 'Rule change',
  workflow: 'Workflow change',
}

const STATUS_LABEL: Record<ChangeProposal['status'], string> = {
  pending: 'Pending',
  approved: 'Approved',
  rejected: 'Rejected',
}

export function ProposalRow({
  proposal,
  companyId,
  people,
  departments,
}: {
  proposal: ChangeProposal
  companyId: string
  people: Map<number, Person>
  departments: Map<number, Department>
}) {
  const [expanded, setExpanded] = useState(false)
  const rerouted = proposal.impact.rerouted.length
  const broken = proposal.impact.broken.length
  const selfApproval = proposal.impact.self_approval.length

  return (
    <div className="rounded-lg border border-border bg-card">
      <button
        type="button"
        onClick={() => setExpanded((value) => !value)}
        aria-expanded={expanded}
        className="flex w-full items-center justify-between gap-4 px-4 py-3 text-left"
      >
        <div>
          <div className="text-[14px] font-semibold">{proposal.title}</div>
          <div className="mt-0.5 text-[12px] text-muted-foreground">
            {KIND_LABEL[proposal.kind]} · proposed by {proposal.proposed_by === 'agent' ? 'Keel agent' : 'a person'} ·{' '}
            {STATUS_LABEL[proposal.status]}
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-3 text-[12px] tabular-nums">
          <Count label="rerouted" value={rerouted} />
          <Count label="broken" value={broken} danger />
          <Count label="self-approval" value={selfApproval} danger />
        </div>
      </button>

      {expanded && (
        <div className="space-y-4 border-t border-border px-4 py-4">
          <ImpactSummaryCards rerouted={rerouted} broken={broken} selfApproval={selfApproval} />

          <div>
            <h3 className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              What changes
            </h3>
            <ProposalDiff diff={proposal.diff} people={people} departments={departments} />
          </div>

          <ApproveRejectBar companyId={companyId} proposal={proposal} brokenCount={broken} />
        </div>
      )}
    </div>
  )
}
