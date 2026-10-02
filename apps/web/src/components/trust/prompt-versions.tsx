import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, PromptVersion } from 'api-types'
import { api } from '../../lib/api'
import { promptVersionsQueryKey } from './eval-query-keys'
import { formatAccuracy } from './format'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'

function VersionRow({ companyId, version, canPromote }: { companyId: string; version: PromptVersion; canPromote: boolean }) {
  const queryClient = useQueryClient()
  const promote = useMutation({
    mutationFn: (confirm: boolean) =>
      api.post<Envelope<PromptVersion>>(`/companies/${companyId}/prompt_versions/${version.id}/promote`, confirm ? { confirm: true } : {}),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: promptVersionsQueryKey(companyId) }),
  })

  const run = version.latest_run
  const blocked = promote.isError
  const regressionNote =
    version.regressions === null
      ? 'Not evaluated yet — run the suite with this version first.'
      : version.regressions.length > 0
        ? `Would regress ${version.regressions.length} ${version.regressions.length === 1 ? 'case' : 'cases'}: ${version.regressions.join(', ')}`
        : null

  return (
    <li aria-label={`${version.key} v${version.version}`} className="space-y-1.5 py-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-mono text-[13px] font-medium">
          {version.key} v{version.version}
        </span>
        {version.active && <Badge variant="success">Active</Badge>}
        {run && (
          <span className="text-[12px] text-muted-foreground">
            {formatAccuracy(run.accuracy)} accuracy
            {run.stability !== null && ` · ${formatAccuracy(run.stability)} stable`}
          </span>
        )}
      </div>
      {version.notes && <p className="text-[13px] text-muted-foreground">{version.notes}</p>}

      {!version.active && (
        <>
          {regressionNote && <p className="text-[12px] text-warning">{regressionNote}</p>}
          {canPromote && (
            <div className="flex flex-wrap items-center gap-2">
              <Button type="button" size="sm" variant="outline" onClick={() => promote.mutate(false)} disabled={promote.isPending}>
                Promote v{version.version}
              </Button>
              {blocked && (
                <Button type="button" size="sm" variant="destructive" onClick={() => promote.mutate(true)} disabled={promote.isPending}>
                  Promote anyway
                </Button>
              )}
            </div>
          )}
          {blocked && <p className="text-[12px] text-destructive">{(promote.error as Error).message}</p>}
        </>
      )}
    </li>
  )
}

/**
 * The prompt versions behind each AI feature (SPEC.md section 12): which one
 * is active, how each scored on its latest run, and Promote — which the API
 * refuses if the challenger regresses a case the active version passes,
 * unless confirmed.
 */
export function PromptVersions({ companyId, canPromote }: { companyId: string; canPromote: boolean }) {
  const query = useQuery({
    queryKey: promptVersionsQueryKey(companyId),
    queryFn: () => api.get<Envelope<PromptVersion[]>>(`/companies/${companyId}/prompt_versions`),
  })

  const versions = query.data?.data ?? []
  if (query.isError) return <p className="text-[13px] text-destructive">{(query.error as Error).message}</p>
  if (versions.length === 0) return null

  return (
    <Card role="region" aria-label="Prompt versions">
      <h2 className="text-[12px] font-semibold uppercase tracking-wide text-muted-foreground">Prompt versions</h2>
      <ul className="divide-y divide-border">
        {versions.map((version) => (
          <VersionRow key={version.id} companyId={companyId} version={version} canPromote={canPromote} />
        ))}
      </ul>
    </Card>
  )
}
