import { useCallback, useState } from 'react'
import { useChannel } from '../../lib/cable'
import type { AssembleEvent } from './assemble-event'
import { isComplete, STAGES, stageStatus, summarize } from './stage-progress'
import { describeAssembleEvent } from './describe-assemble-event'

const STATUS_DOT: Record<string, string> = {
  pending: 'bg-muted-foreground/30',
  active: 'bg-primary animate-pulse',
  done: 'bg-primary',
}

export function AssembleProgress({ companyId }: { companyId: string }) {
  const [events, setEvents] = useState<AssembleEvent[]>([])

  // Stable across re-renders so useChannel's effect subscribes once and
  // doesn't tear down/resubscribe on every incoming event.
  const onEvent = useCallback((event: AssembleEvent) => {
    setEvents((previous) => [...previous, event])
  }, [])

  useChannel<AssembleEvent>('AssembleChannel', { company_id: companyId }, onEvent)

  const progress = events[events.length - 1]?.progress ?? 0
  const complete = isComplete(events)
  const summary = summarize(events)

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

      {complete ? (
        <p className="rounded-lg border border-border bg-secondary px-4 py-3 text-[13px]">
          {summary.people} people, {summary.departments} departments, {summary.policies} policies, {summary.rules}{' '}
          rules, {summary.workflows} workflows.
        </p>
      ) : (
        events.length === 0 && (
          <p className="text-[13px] text-muted-foreground">Waiting for Assemble to start…</p>
        )
      )}

      <ul className="space-y-1 text-[13px] text-muted-foreground">
        {events.map((event, index) => (
          <li key={index}>{describeAssembleEvent(event)}</li>
        ))}
      </ul>
    </div>
  )
}
