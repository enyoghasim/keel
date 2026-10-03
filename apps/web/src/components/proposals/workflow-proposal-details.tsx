import type { Person, WorkflowChangeProposal, WorkflowImpactStep } from 'api-types'
import { useMemo } from 'react'
import { FlowCanvas } from '../workflows/flow-canvas'
import { mergeWorkflowSteps } from '../workflows/flow-graph'
import { Card } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

function Stat({ label, value, danger }: { label: string; value: number; danger?: boolean }) {
  return (
    <Card role="group" aria-label={label} className={`gap-0 px-4 py-3 ${danger && value > 0 ? 'border-destructive-muted bg-destructive-muted' : ''}`}>
      <div className={`text-2xl font-bold tabular-nums ${danger && value > 0 ? 'text-destructive' : ''}`}>{value}</div>
      <div className="text-[12px] text-muted-foreground">{label}</div>
    </Card>
  )
}

// What a person's steps gained, as "step → who it resolves to".
function gainedSteps(before: WorkflowImpactStep[], after: WorkflowImpactStep[], people: Map<number, Person>): string {
  const had = new Set(before.map((s) => `${s.step_key}:${s.person_id}`))
  const gained = after.filter((s) => !had.has(`${s.step_key}:${s.person_id}`))
  if (gained.length === 0) return 'Fewer steps'
  return gained.map((s) => `${s.step_key} → ${s.person_id === null ? 'nobody' : (people.get(s.person_id)?.name ?? `Person #${s.person_id}`)}`).join(', ')
}

const SAMPLE_LIMIT = 10

// The body of a workflow proposal (SPEC.md sections 8 and 10): the proposed
// graph with added steps outlined green, removed red and changed amber, and
// what the dry-run of the old and new workflow says it does to people.
export function WorkflowProposalDetails({ proposal, people }: { proposal: WorkflowChangeProposal; people: Map<number, Person> }) {
  const { diff, impact } = proposal
  const merged = useMemo(() => mergeWorkflowSteps(diff.before, diff.after), [diff.before, diff.after])
  const workflow = useMemo(
    () => ({
      id: diff.workflow_id,
      name: proposal.title,
      status: 'active' as const,
      version: 0,
      trigger: { request_kind: diff.request_kind },
      steps: merged.steps,
      created_at: proposal.created_at,
    }),
    [diff.workflow_id, diff.request_kind, merged.steps, proposal.title, proposal.created_at],
  )
  const peopleList = useMemo(() => [...people.values()], [people])

  return (
    <div className="space-y-4">
      <blockquote className="border-l-2 border-border pl-3 text-[13px] text-muted-foreground">“{diff.instruction}”</blockquote>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="Steps added" value={impact.steps.added.length} />
        <Stat label="Steps removed" value={impact.steps.removed.length} />
        <Stat label="People affected" value={impact.affected_count} />
        <Stat label="Broken steps" value={impact.broken.length} danger />
      </div>

      <FlowCanvas workflow={workflow} people={peopleList} diffStatus={merged.status} />

      {(impact.broken.length > 0 || impact.in_flight > 0) && (
        <ul aria-label="Problems this change creates" className="space-y-1.5">
          {impact.broken.map((broken) => (
            <li key={broken.step_key} className="rounded border border-destructive/30 bg-destructive-muted px-3 py-2 text-[13px] text-destructive">
              <strong>{broken.step_key}</strong>: {broken.reference} resolves to nobody for {broken.person_count}{' '}
              {broken.person_count === 1 ? 'person' : 'people'}
            </li>
          ))}
          {impact.in_flight > 0 && (
            <li className="rounded border border-warning/30 bg-warning-muted px-3 py-2 text-[13px] text-warning">
              {impact.in_flight} open {impact.in_flight === 1 ? 'request is' : 'requests are'} waiting on a step this removes.
            </li>
          )}
        </ul>
      )}

      {impact.affected.length > 0 && (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Requester</TableHead>
              <TableHead>What they gain</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {impact.affected.slice(0, SAMPLE_LIMIT).map((row, index) => (
              <TableRow key={`${row.person_id}-${index}`}>
                <TableCell>{people.get(row.person_id)?.name ?? `Person #${row.person_id}`}</TableCell>
                <TableCell>{gainedSteps(row.before, row.after, people)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
      {impact.affected_count > SAMPLE_LIMIT && (
        <p className="text-[12px] text-muted-foreground">…and {impact.affected_count - SAMPLE_LIMIT} more people.</p>
      )}
    </div>
  )
}
