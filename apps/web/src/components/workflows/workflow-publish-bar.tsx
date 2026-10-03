import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { Envelope, Workflow } from 'api-types'
import { api } from '../../lib/api'
import { Button } from '@/components/ui/button'

// A draft workflow (built by Assemble, or still mid-edit) never runs real
// requests — Workflows::Runtime only looks at status "active" ones, so a
// request needing approval fails outright until this is published. Shown
// right above the canvas, not just as a small tab badge, so that's obvious
// before someone goes looking for why a real request errored.
export function WorkflowPublishBar({ companyId, workflow }: { companyId: string; workflow: Workflow }) {
  const queryClient = useQueryClient()

  const publish = useMutation({
    mutationFn: () => api.post<Envelope<Workflow>>(`/companies/${companyId}/workflows/${workflow.id}/publish`, {}),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['workflow', companyId, workflow.id] })
      void queryClient.invalidateQueries({ queryKey: ['workflows', companyId] })
    },
  })

  return (
    <div className="flex flex-wrap items-center gap-2.5 rounded border border-warning/40 bg-warning-muted px-3 py-2">
      <p className="text-[13px] text-warning">
        <strong className="font-semibold">Draft</strong> — not yet enforced. A request that needs approval will fail until this is published.
      </p>
      <Button type="button" size="sm" disabled={publish.isPending} onClick={() => publish.mutate()} className="ml-auto shrink-0">
        {publish.isPending ? 'Publishing…' : 'Publish'}
      </Button>
      {publish.isError && <p className="w-full text-[12px] text-destructive">{(publish.error as Error).message}</p>}
    </div>
  )
}
