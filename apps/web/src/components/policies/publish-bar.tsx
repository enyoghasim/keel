import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { Envelope, PolicyWithRules } from 'api-types'
import { api } from '../../lib/api'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'

// A draft policy goes live only with no open questions (SPEC.md section 7):
// the deliberate friction. The API enforces it too.
export function PublishBar({ companyId, policy }: { companyId: string; policy: PolicyWithRules }) {
  const queryClient = useQueryClient()
  const open = policy.rules.filter((rule) => rule.ambiguities.length > 0).length

  const publish = useMutation({
    mutationFn: () => api.post<Envelope<PolicyWithRules>>(`/companies/${companyId}/policies/${policy.id}/publish`, {}),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['policy', companyId, policy.id] })
      void queryClient.invalidateQueries({ queryKey: ['policies', companyId] })
    },
  })

  return (
    <div className="flex flex-wrap items-center gap-3">
      <Badge variant={policy.status === 'active' ? 'success' : 'secondary'}>
        {policy.status === 'active' ? 'Active' : 'Draft'} · v{policy.version}
      </Badge>
      {policy.status !== 'active' && (
        <>
          <Button type="button" size="sm" disabled={open > 0 || publish.isPending} onClick={() => publish.mutate()}>
            Publish
          </Button>
          {open > 0 && (
            <span className="text-[12px] text-muted-foreground">
              Answer {open === 1 ? 'the open question' : `${open} open questions`} before publishing.
            </span>
          )}
        </>
      )}
      {publish.isError && <span className="text-[12px] text-destructive">{(publish.error as Error).message}</span>}
    </div>
  )
}
