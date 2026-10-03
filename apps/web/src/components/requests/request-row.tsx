import type { Person, Request, RequestStatus } from 'api-types'
import { Badge } from '@/components/ui/badge'
import { Card } from '@/components/ui/card'

function humanize(key: string) {
  return key.replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function payloadSummary(payload: Record<string, unknown>) {
  const entries = Object.entries(payload)
  if (entries.length === 0) return null
  return entries.map(([key, value]) => `${humanize(key)}: ${value}`).join(' · ')
}

const STATUS_LABEL: Record<RequestStatus, string> = {
  pending: 'Pending',
  approved: 'Approved',
  rejected: 'Rejected',
  blocked: 'Blocked',
}

const STATUS_VARIANT: Record<RequestStatus, 'success' | 'warning' | 'destructive'> = {
  pending: 'warning',
  approved: 'success',
  rejected: 'destructive',
  blocked: 'destructive',
}

const STEP_STATUS_LABEL: Record<string, string> = {
  pending: 'Waiting',
  done: 'Done',
  rejected: 'Rejected',
  cancelled: 'Cancelled',
}

export function RequestRow({ request, people }: { request: Request; people: Map<number, Person> }) {
  const date = new Date(request.created_at).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
  const steps = request.workflow_run?.step_runs ?? []

  return (
    <Card className="gap-0 p-0">
      <div className="flex flex-col gap-1.5 px-4 py-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4">
        <div className="min-w-0">
          <div className="text-[14px] font-semibold">{humanize(request.kind)} request</div>
          <div className="mt-0.5 text-[12px] text-muted-foreground">
            {payloadSummary(request.payload) ?? 'No details'} · submitted {date}
          </div>
        </div>
        <Badge variant={STATUS_VARIANT[request.status]} className="shrink-0">
          {STATUS_LABEL[request.status]}
        </Badge>
      </div>

      {steps.length > 0 && (
        <ol className="space-y-1.5 border-t border-border px-4 py-3">
          {steps.map((step) => {
            const assignee = step.resolved_person_id !== null ? people.get(step.resolved_person_id) : null
            return (
              <li key={step.id} className="flex items-center justify-between gap-3 text-[12.5px]">
                <span className="text-foreground">
                  {humanize(step.step_key)}
                  {assignee ? ` · ${assignee.name}` : step.reference ? ` · ${step.reference}` : ''}
                </span>
                <span className="shrink-0 text-muted-foreground">
                  {STEP_STATUS_LABEL[step.status] ?? step.status}
                  {step.overridden ? ' (overridden)' : ''}
                </span>
              </li>
            )
          })}
        </ol>
      )}
    </Card>
  )
}
