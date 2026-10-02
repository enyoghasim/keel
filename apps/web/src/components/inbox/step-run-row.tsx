import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { Envelope, Person, Request, StepRun } from 'api-types'
import { api } from '../../lib/api'
import { OverrideDialog } from './override-dialog'

function humanize(key: string) {
  return key.replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function payloadSummary(payload: Record<string, unknown>) {
  const entries = Object.entries(payload)
  if (entries.length === 0) return null
  return entries.map(([key, value]) => `${humanize(key)}: ${value}`).join(' · ')
}

export function StepRunRow({
  companyId,
  request,
  stepRun,
  people,
}: {
  companyId: string
  request: Request
  stepRun: StepRun
  people: Map<number, Person>
}) {
  const queryClient = useQueryClient()
  const requester = people.get(request.requester_id)
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['requests', companyId] })

  const act = useMutation({
    mutationFn: (variables: { step_action: string; reason?: string }) =>
      api.post<Envelope<StepRun>>(`/step_runs/${stepRun.id}/act`, variables),
    onSuccess: invalidate,
  })

  return (
    <div className="space-y-2 rounded-lg border border-border bg-card px-4 py-3">
      <div className="flex items-center justify-between gap-4">
        <div className="min-w-0">
          <div className="text-[14px] font-semibold">
            {humanize(request.kind)} request from {requester?.name ?? `person #${request.requester_id}`}
          </div>
          <div className="mt-0.5 truncate text-[12px] text-muted-foreground">
            {humanize(stepRun.step_key)}
            {payloadSummary(request.payload) ? ` · ${payloadSummary(request.payload)}` : ''}
          </div>
        </div>

        <div className="flex shrink-0 items-center gap-2">
          <button
            type="button"
            onClick={() => act.mutate({ step_action: 'approve' })}
            disabled={act.isPending}
            className="rounded bg-primary px-3.5 py-1.5 text-[13px] font-medium text-primary-foreground shadow-btn disabled:cursor-not-allowed disabled:opacity-40"
          >
            Approve
          </button>
          <button
            type="button"
            onClick={() => act.mutate({ step_action: 'reject' })}
            disabled={act.isPending}
            className="rounded border border-border bg-card px-3.5 py-1.5 text-[13px] font-medium disabled:cursor-not-allowed disabled:opacity-40"
          >
            Reject
          </button>
          <OverrideDialog
            pending={act.isPending}
            onSubmit={(reason) => act.mutate({ step_action: 'override', reason })}
          />
        </div>
      </div>

      {act.isError && <p className="text-[13px] text-destructive">{(act.error as Error).message}</p>}
    </div>
  )
}
