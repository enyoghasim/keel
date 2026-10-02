import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { Envelope } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { workspaceQueryKey } from '../../lib/workspace'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'

/**
 * "Reset demo" (SPEC.md section 18): visitors to a public demo will change
 * things, so an hr_admin can wipe the deployment back to a freshly seeded
 * Nubo Logistics. Destructive, so it asks twice, and the server only offers it
 * where DEMO_RESET is on. Everyone is signed out afterwards, because the
 * people they were no longer exist.
 */
export function DemoResetPanel({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const [confirming, setConfirming] = useState(false)

  const reset = useMutation({
    mutationFn: () => api.post<Envelope<unknown>>(`/companies/${companyId}/demo_reset`, {}),
    onSuccess: () => {
      // Back to a browser that has seen nothing: it learns the company and who it is afresh.
      queryClient.clear()
      void queryClient.invalidateQueries({ queryKey: workspaceQueryKey })
      window.location.assign('/')
    },
  })

  return (
    <Card role="region" aria-label="Reset demo">
      <h2 className="text-[15px] font-semibold">Reset demo</h2>
      <p className="mt-1 text-[13px] text-muted-foreground">
        Wipes everything on this deployment (people, policies, requests, proposals, tokens) and reloads Nubo Logistics.
        Everyone is signed out.
      </p>
      {confirming ? (
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <span className="text-[13px] font-medium">Really wipe and reload?</span>
          <Button type="button" variant="destructive" size="sm" disabled={reset.isPending} onClick={() => reset.mutate()}>
            {reset.isPending ? 'Resetting…' : 'Yes, reset the demo'}
          </Button>
          <Button type="button" variant="outline" size="sm" disabled={reset.isPending} onClick={() => setConfirming(false)}>
            Cancel
          </Button>
        </div>
      ) : (
        <Button type="button" variant="outline" size="sm" className="mt-3" onClick={() => setConfirming(true)}>
          Reset demo
        </Button>
      )}
      {reset.isError && <p className="mt-2 text-[13px] text-destructive">{(reset.error as Error).message}</p>}
    </Card>
  )
}
