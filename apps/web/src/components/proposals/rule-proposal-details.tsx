import type { BacktestFlip, Person, RuleChangeProposal, RuleSnapshot } from 'api-types'
import { describeRule } from '../policies/describe-rule'
import { Card } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

const OUTCOME_LABEL: Record<BacktestFlip['before'], string> = {
  auto_approve: 'Auto-approved',
  require_approval: 'Sent for approval',
  reject: 'Rejected',
  blocked: 'Blocked',
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <Card className="gap-0 px-4 py-3">
      <div className="text-2xl font-bold tabular-nums">{value}</div>
      <div className="text-[12px] text-muted-foreground">{label}</div>
    </Card>
  )
}

function RuleSide({ label, rule }: { label: 'before' | 'after'; rule: RuleSnapshot }) {
  return (
    <div
      role="group"
      aria-label={`${rule.key} ${label}`}
      className={`rounded border px-3 py-2 text-[13px] ${label === 'after' ? 'border-info bg-info-muted' : 'border-border bg-secondary'}`}
    >
      <div className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{label}</div>
      {describeRule(rule.conditions, rule.actions)}
    </div>
  )
}

const FLIP_LIMIT = 20

function amountOf(flip: BacktestFlip): string {
  const amount = flip.payload.amount_eur
  if (typeof amount === 'number') return `€${amount.toLocaleString('en')}`
  const days = flip.payload.days
  return typeof days === 'number' ? `${days} days` : '—'
}

// The body of a rule proposal (SPEC.md section 10): the rewritten rules
// side by side, with the handbook quote they came from, and the backtest of
// what would have happened to past requests.
export function RuleProposalDetails({ proposal, people }: { proposal: RuleChangeProposal; people: Map<number, Person> }) {
  const { backtest } = proposal.impact

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3">
        <Stat label="Past requests replayed" value={backtest.total} />
        <Stat label="Decisions flipped" value={backtest.flipped_count} />
      </div>
      <p className="text-[13px]">{backtest.summary}</p>
      {backtest.new_conflicts.length > 0 && (
        <ul aria-label="Conflicts this change creates" className="space-y-1.5">
          {backtest.new_conflicts.map((conflict) => (
            <li key={conflict.rules.join('|')} className="rounded border border-warning/30 bg-warning-muted px-3 py-2 text-[13px] text-warning">
              {conflict.warning}
            </li>
          ))}
        </ul>
      )}

      <div>
        <h3 className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">What changes</h3>
        <div className="space-y-3">
          {proposal.diff.after.map((after, index) => (
            <div key={after.key} className="space-y-1.5">
              <div className="grid gap-2 sm:grid-cols-2">
                <RuleSide label="before" rule={proposal.diff.before[index]} />
                <RuleSide label="after" rule={after} />
              </div>
              <blockquote className="border-l-2 border-border pl-3 text-[12px] text-muted-foreground">
                {after.source_quote}
              </blockquote>
            </div>
          ))}
        </div>
      </div>

      {backtest.flipped.length > 0 && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Requester</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Decision</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {backtest.flipped.slice(0, FLIP_LIMIT).map((flip, index) => (
              <TableRow key={flip.request_id ?? index}>
                <TableCell>{people.get(flip.requester_id)?.name ?? `Person #${flip.requester_id}`}</TableCell>
                <TableCell>{amountOf(flip)}</TableCell>
                <TableCell>{`${OUTCOME_LABEL[flip.before]} → ${OUTCOME_LABEL[flip.after]}`}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
      {backtest.flipped.length > FLIP_LIMIT && (
        <p className="text-[12px] text-muted-foreground">…and {backtest.flipped.length - FLIP_LIMIT} more.</p>
      )}
    </div>
  )
}
