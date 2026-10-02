import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import type { Envelope } from 'api-types'
import { useCallback, useMemo, useState } from 'react'
import { api } from '../../lib/api'
import { useChannel } from '../../lib/cable'
import { type AssembleEvent, mergeEvents } from './assemble-event'
import { failure, furthestProgress, importIssues, isComplete, lowConfidenceMappings, STAGES, stageStatus, summarize } from './stage-progress'
import { describeAssembleEvent } from './describe-assemble-event'

const STATUS_DOT: Record<string, string> = {
  pending: 'bg-muted-foreground/30',
  active: 'bg-primary animate-pulse',
  done: 'bg-primary',
}

export function AssembleProgress({ companyId }: { companyId: string }) {
  const [live, setLive] = useState<AssembleEvent[]>([])

  // What the job did before this page subscribed (or before a reload): the
  // API keeps every numbered event, and the page merges it with the live ones.
  const log = useQuery({
    queryKey: ['assemble-events', companyId],
    queryFn: () => api.get<Envelope<AssembleEvent[]>>(`/companies/${companyId}/assemble_events`),
    staleTime: Infinity,
    retry: false,
  })
  const events = useMemo(() => mergeEvents(log.data?.data ?? [], live), [log.data, live])

  // Stable across re-renders so useChannel's effect subscribes once and
  // doesn't tear down/resubscribe on every incoming event.
  const onEvent = useCallback((event: AssembleEvent) => {
    setLive((previous) => [...previous, event])
  }, [])
  // Fetch again once the subscription is live: events stored between the first
  // fetch and the subscribe confirmation are in neither.
  const { refetch } = log
  const refetchLog = useCallback(() => void refetch(), [refetch])

  useChannel<AssembleEvent>('AssembleChannel', { company_id: companyId }, onEvent, refetchLog)

  const progress = furthestProgress(events)
  const failedBecause = failure(events)
  const complete = isComplete(events)
  const summary = summarize(events)
  const columnsToCheck = lowConfidenceMappings(events)
  const issues = importIssues(events)

  return (
    <div className="space-y-5">
      <div>
        <div className="h-1.5 w-full overflow-hidden rounded-full bg-secondary" role="progressbar" aria-valuenow={Math.round(progress * 100)}>
          <div
            className="h-full rounded-full bg-primary transition-all"
            style={{ width: `${Math.round(progress * 100)}%` }}
          />
        </div>
        <ol className="mt-3 flex flex-wrap gap-4 text-[12px]">
          {STAGES.map((stage) => {
            const status = stageStatus(stage, events)
            return (
              <li key={stage.key} className="flex items-center gap-1.5">
                <span className={`h-2 w-2 rounded-full ${STATUS_DOT[status]}`} />
                <span className={status === 'pending' ? 'text-muted-foreground' : ''}>{stage.label}</span>
              </li>
            )
          })}
        </ol>
      </div>

      {failedBecause && (
        <p role="alert" className="rounded border border-destructive/40 bg-destructive/10 px-3 py-2.5 text-[13px] text-destructive">
          Assemble stopped: {failedBecause}
        </p>
      )}

      {complete ? (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-secondary px-4 py-3 text-[13px]">
          <p>
            {summary.people} people, {summary.departments} departments, {summary.policies} policies, {summary.rules}{' '}
            rules{summary.needInput > 0 && ` (${summary.needInput} need your input)`}, {summary.workflows} workflows.
          </p>
          <Link to="/policies" className="font-medium underline">
            Go to policies
          </Link>
        </div>
      ) : (
        events.length === 0 && (
          <p className="text-[13px] text-muted-foreground">Waiting for Assemble to start…</p>
        )
      )}

      {columnsToCheck.length > 0 && (
        <section className="rounded border border-warning/40 bg-warning-muted px-3 py-2.5 text-[12.5px]">
          <h2 className="font-medium">Check these columns</h2>
          <p className="text-muted-foreground">Keel wasn't sure what these CSV columns are.</p>
          <ul className="mt-1.5 space-y-0.5">
            {columnsToCheck.map((m) => (
              <li key={m.source_column}>
                “{m.source_column}” → {m.field} ({Math.round(m.confidence * 100)}% sure)
              </li>
            ))}
          </ul>
        </section>
      )}

      {issues.length > 0 && (
        <section className="rounded border border-warning/40 bg-warning-muted px-3 py-2.5 text-[12.5px]">
          <h2 className="font-medium">Import issues ({issues.length})</h2>
          <ul className="mt-1.5 space-y-0.5">
            {issues.map((issue) => (
              <li key={issue.id}>
                Row {issue.row_number}: {issue.message}
              </li>
            ))}
          </ul>
        </section>
      )}

      <ul className="max-h-80 space-y-1 overflow-y-auto text-[13px] text-muted-foreground">
        {events.map((event, index) => (
          <li key={index}>{describeAssembleEvent(event)}</li>
        ))}
      </ul>
    </div>
  )
}
