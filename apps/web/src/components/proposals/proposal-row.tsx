import type { ChangeProposal, Department, Person } from 'api-types'
import { useState } from 'react'
import { Card } from '@/components/ui/card'
import { ApproveRejectBar } from './approve-reject-bar'
import { ImpactSummaryCards } from './impact-summary-cards'
import { ProposalDiff } from './proposal-diff'
import { RuleProposalDetails } from './rule-proposal-details'

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
  canDecide,
}: {
  proposal: ChangeProposal
  companyId: string
  people: Map<number, Person>
  departments: Map<number, Department>
  canDecide: boolean
}) {
  const [expanded, setExpanded] = useState(false)
  const broken = proposal.kind === 'org' ? proposal.impact.broken.length : 0

  return (
    <Card className="gap-0 p-0">
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
          {proposal.kind === 'org' && (
            <>
              <Count label="rerouted" value={proposal.impact.rerouted.length} />
              <Count label="broken" value={broken} danger />
              <Count label="self-approval" value={proposal.impact.self_approval.length} danger />
            </>
          )}
          {proposal.kind === 'rule' && <Count
              label={proposal.impact.backtest.flipped_count === 1 ? 'decision flipped' : 'decisions flipped'}
              value={proposal.impact.backtest.flipped_count}
            />}
        </div>
      </button>

      {expanded && (
        <div className="space-y-4 border-t border-border px-4 py-4">
          {proposal.kind === 'org' && (
            <>
              <ImpactSummaryCards
                rerouted={proposal.impact.rerouted.length}
                broken={broken}
                selfApproval={proposal.impact.self_approval.length}
              />

              <div>
                <h3 className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                  What changes
                </h3>
                <ProposalDiff diff={proposal.diff} people={people} departments={departments} />
              </div>
            </>
          )}
          {proposal.kind === 'rule' && <RuleProposalDetails proposal={proposal} people={people} />}
          {proposal.kind === 'workflow' && (
            <p className="text-[13px] text-muted-foreground">Workflow proposals can't be previewed yet.</p>
          )}

          <ApproveRejectBar companyId={companyId} proposal={proposal} brokenCount={broken} canDecide={canDecide} />
        </div>
      )}
    </Card>
  )
}
