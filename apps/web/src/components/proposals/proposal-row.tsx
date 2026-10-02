import { useQuery } from '@tanstack/react-query'
import type { AgentRun, ChangeProposal, Department, Envelope, Person } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { TraceDrawer } from '../agent/trace-drawer'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { ApproveRejectBar } from './approve-reject-bar'
import { ImpactSummaryCards } from './impact-summary-cards'
import { ProposalDiff } from './proposal-diff'
import { RuleProposalDetails } from './rule-proposal-details'
import { WorkflowProposalDetails } from './workflow-proposal-details'

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

const BLOCKER_LABEL: Record<ChangeProposal['kind'], { singular: string; plural: string }> = {
  org: { singular: 'broken chain', plural: 'broken chains' },
  rule: { singular: 'new conflict', plural: 'new conflicts' },
  workflow: { singular: 'broken step', plural: 'broken steps' },
}

// The trace of the agent run that proposed this (AGENTS.md rule 3), for
// the HR admins who decide it — runs themselves are private to whoever asked.
function TraceButton({ companyId, proposalId }: { companyId: string; proposalId: number }) {
  const [open, setOpen] = useState(false)
  const traceQuery = useQuery({
    queryKey: ['change_proposal_trace', companyId, proposalId],
    queryFn: () => api.get<Envelope<AgentRun>>(`/companies/${companyId}/change_proposals/${proposalId}/trace`),
    enabled: open,
  })
  const run = traceQuery.data?.data

  return (
    <div>
      <Button type="button" variant="outline" size="sm" onClick={() => setOpen(true)}>
        View trace
      </Button>
      {traceQuery.isError && open && <p className="mt-1 text-[13px] text-destructive">Couldn't load the trace.</p>}
      {open && run && <TraceDrawer run={run} onClose={() => setOpen(false)} />}
    </div>
  )
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
  // What holds Approve behind "Approve anyway": broken chains, broken steps, or rules that now conflict.
  const broken = proposal.kind === 'rule' ? proposal.impact.backtest.new_conflicts.length : proposal.impact.broken.length
  const blocker = BLOCKER_LABEL[proposal.kind]

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
          {proposal.kind === 'workflow' && (
            <>
              <Count label="people affected" value={proposal.impact.affected_count} />
              <Count label="broken" value={broken} danger />
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
          {proposal.kind === 'workflow' && <WorkflowProposalDetails proposal={proposal} people={people} />}

          {canDecide && proposal.agent_run_id !== null && <TraceButton companyId={companyId} proposalId={proposal.id} />}

          <ApproveRejectBar companyId={companyId} proposal={proposal} brokenCount={broken} blocker={blocker} canDecide={canDecide} />
        </div>
      )}
    </Card>
  )
}
