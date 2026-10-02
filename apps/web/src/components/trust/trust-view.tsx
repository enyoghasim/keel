import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { EvalRun, EvalRunsMeta, Envelope } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { useCurrentPerson } from '../../lib/auth'
import { PagePlaceholder } from '../layout/page-placeholder'
import { AccuracyTrend } from './accuracy-trend'
import { evalRunsQueryKey } from './eval-query-keys'
import { EvalRunWatcher } from './eval-run-watcher'
import { RunCompare } from './run-compare'
import { RunDetail } from './run-detail'
import { RunList } from './run-list'
import { Scoreboard } from './scoreboard'

export function TrustView({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const [selectedRunId, setSelectedRunId] = useState<number | null>(null)
  const [compareIds, setCompareIds] = useState<number[]>([])

  const currentPerson = useCurrentPerson(companyId).data?.data
  const runsQuery = useQuery({
    queryKey: evalRunsQueryKey(companyId),
    queryFn: () => api.get<Envelope<EvalRun[]>>(`/companies/${companyId}/eval_runs`),
  })

  const startRun = useMutation({
    mutationFn: () => api.post<Envelope<EvalRun>>(`/companies/${companyId}/eval_runs`, { suite: 'insights' }),
    onSuccess: (response) => {
      const run = response.data
      if (!run) return
      queryClient.setQueryData<Envelope<EvalRun[]>>(evalRunsQueryKey(companyId), (list) =>
        list && { ...list, data: [run, ...(list.data ?? [])] },
      )
      setSelectedRunId(run.id)
      setCompareIds([])
    },
  })

  if (runsQuery.isPending) return <PagePlaceholder note="Loading eval runs…" />
  if (runsQuery.isError) return <PagePlaceholder note={`Couldn't load eval runs: ${(runsQuery.error as Error).message}`} />

  const runs = runsQuery.data.data ?? []
  const meta = runsQuery.data.meta as EvalRunsMeta
  const activeRuns = runs.filter((run) => run.status === 'pending' || run.status === 'running')
  const canRun = currentPerson?.roles.includes('hr_admin') ?? false
  const shownRunId = selectedRunId ?? runs[0]?.id ?? null

  return (
    <div className="space-y-6">
      {activeRuns.map((run) => (
        <EvalRunWatcher key={run.id} companyId={companyId} runId={run.id} />
      ))}

      <Scoreboard runs={runs} meta={meta} />

      <div className="flex items-center justify-between gap-4">
        <p className="text-[13px] text-muted-foreground">
          {canRun
            ? 'Each run sends every active insights case through Insights::Interpreter and scores the result field by field.'
            : 'Only an hr_admin can start an eval run.'}
        </p>
        {canRun && (
          <button
            type="button"
            onClick={() => startRun.mutate()}
            disabled={startRun.isPending || activeRuns.length > 0}
            className="shrink-0 rounded-lg bg-primary px-4 py-2 text-[13px] font-medium text-primary-foreground shadow-btn disabled:cursor-not-allowed disabled:opacity-40"
          >
            {activeRuns.length > 0 ? 'Run in progress…' : 'Run insights suite'}
          </button>
        )}
      </div>
      {startRun.isError && <p className="text-[13px] text-destructive">{(startRun.error as Error).message}</p>}

      {runs.length === 0 ? (
        <PagePlaceholder note="No eval runs yet. Start one to score how well Keel understands analytics questions." />
      ) : (
        <>
          <AccuracyTrend runs={runs.filter((run) => run.suite === 'insights')} />
          <div className="rounded-lg border border-border bg-card p-4 shadow-xs">
            <RunList
              runs={runs}
              selectedRunId={shownRunId}
              compareIds={compareIds}
              onSelect={(id) => {
                setSelectedRunId(id)
                setCompareIds([])
              }}
              onToggleCompare={(id) =>
                setCompareIds((ids) => (ids.includes(id) ? ids.filter((x) => x !== id) : [...ids, id].slice(-2)))
              }
            />
            <p className="mt-2 text-[12px] text-subtle-foreground">Tick two completed runs to compare them.</p>
          </div>
          {compareIds.length === 2 ? (
            <RunCompare companyId={companyId} runIds={[compareIds[0], compareIds[1]]} />
          ) : (
            shownRunId !== null && <RunDetail key={shownRunId} companyId={companyId} runId={shownRunId} />
          )}
        </>
      )}
    </div>
  )
}
