import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { EvalRun, EvalRunsMeta, EvalSuite, Envelope, PromptVersion } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { useCurrentPerson } from '../../lib/auth'
import { PagePlaceholder } from '../layout/page-placeholder'
import { AccuracyTrend } from './accuracy-trend'
import { CandidateQueue } from './candidate-queue'
import { evalRunsQueryKey, promptVersionsQueryKey } from './eval-query-keys'
import { EvalRunWatcher } from './eval-run-watcher'
import { SUITE_LABELS } from './format'
import { PromptVersions } from './prompt-versions'
import { RunCompare } from './run-compare'
import { RunDetail } from './run-detail'
import { RunList } from './run-list'
import { Scoreboard } from './scoreboard'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'

const SUITE_BLURBS: Record<EvalSuite, string> = {
  insights: 'Each run sends every active insights case through Insights::Interpreter and scores the result field by field.',
  policy_extraction:
    'Each run compiles every active handbook passage into rules and scores them by behaviour on probe requests, plus verbatim quotes and flagged ambiguities.',
  agent: 'Each run replays every active agent case as its person, scores the tools it called and the outcome, and has a judge grade the answer. Nothing it does is saved.',
}

export function TrustView({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const [selectedRunId, setSelectedRunId] = useState<number | null>(null)
  const [compareIds, setCompareIds] = useState<number[]>([])
  const [suite, setSuite] = useState<EvalSuite>('insights')
  const [promptVersionId, setPromptVersionId] = useState('')
  const [stabilitySamples, setStabilitySamples] = useState(0)

  const currentPerson = useCurrentPerson(companyId).data?.data
  const runsQuery = useQuery({
    queryKey: evalRunsQueryKey(companyId),
    queryFn: () => api.get<Envelope<EvalRun[]>>(`/companies/${companyId}/eval_runs`),
  })

  const versionsQuery = useQuery({
    queryKey: promptVersionsQueryKey(companyId),
    queryFn: () => api.get<Envelope<PromptVersion[]>>(`/companies/${companyId}/prompt_versions`),
  })

  const startRun = useMutation({
    mutationFn: () =>
      api.post<Envelope<EvalRun>>(`/companies/${companyId}/eval_runs`, {
        suite,
        // Only the policy extraction suite has prompt versions to pick and compiles to sample.
        ...(suite === 'policy_extraction' && promptVersionId ? { prompt_version_id: Number(promptVersionId) } : {}),
        ...(suite === 'policy_extraction' && stabilitySamples > 0 ? { stability_samples: stabilitySamples } : {}),
      }),
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
  const runnableSuites = meta.runnable_suites
  const extractorVersions = (versionsQuery.data?.data ?? []).filter((version) => version.key === 'policy_extractor')
  const shownRunId = selectedRunId ?? runs[0]?.id ?? null

  return (
    <div className="space-y-6">
      {activeRuns.map((run) => (
        <EvalRunWatcher key={run.id} companyId={companyId} runId={run.id} />
      ))}

      <Scoreboard runs={runs} meta={meta} />

      <div className="space-y-3">
        <p className="text-[13px] text-muted-foreground">{canRun ? SUITE_BLURBS[suite] : 'Only an hr_admin can start an eval run.'}</p>
        {canRun && (
          <div className="flex flex-wrap items-end gap-3">
            <label className="text-[12px] font-medium">
              Suite
              <select
                value={suite}
                onChange={(event) => setSuite(event.target.value as EvalSuite)}
                className="mt-1 block rounded border border-border bg-card px-2 py-1.5 text-[13px]"
              >
                {runnableSuites.map((name) => (
                  <option key={name} value={name}>
                    {SUITE_LABELS[name]}
                  </option>
                ))}
              </select>
            </label>
            {suite === 'policy_extraction' && (
              <>
                <label className="text-[12px] font-medium">
                  Prompt version
                  <select
                    value={promptVersionId}
                    onChange={(event) => setPromptVersionId(event.target.value)}
                    className="mt-1 block rounded border border-border bg-card px-2 py-1.5 text-[13px]"
                  >
                    <option value="">Active version</option>
                    {extractorVersions.map((version) => (
                      <option key={version.id} value={version.id}>
                        v{version.version}
                        {version.active ? ' (active)' : ''}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="text-[12px] font-medium">
                  Stability samples
                  <select
                    value={stabilitySamples}
                    onChange={(event) => setStabilitySamples(Number(event.target.value))}
                    className="mt-1 block rounded border border-border bg-card px-2 py-1.5 text-[13px]"
                  >
                    <option value={0}>Off</option>
                    <option value={3}>3 compiles</option>
                    <option value={5}>5 compiles</option>
                  </select>
                </label>
              </>
            )}
            <Button type="button" onClick={() => startRun.mutate()} disabled={startRun.isPending || activeRuns.length > 0} className="shrink-0">
              {activeRuns.length > 0 ? 'Run in progress…' : `Run ${SUITE_LABELS[suite].toLowerCase()} suite`}
            </Button>
          </div>
        )}
      </div>
      {startRun.isError && <p className="text-[13px] text-destructive">{(startRun.error as Error).message}</p>}

      {runs.length === 0 ? (
        <PagePlaceholder note="No eval runs yet. Start one to score how well Keel understands analytics questions." />
      ) : (
        <>
          <AccuracyTrend runs={runs.filter((run) => run.suite === suite)} />
          <Card>
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
          </Card>
          {compareIds.length === 2 ? (
            <RunCompare companyId={companyId} runIds={[compareIds[0], compareIds[1]]} />
          ) : (
            shownRunId !== null && <RunDetail key={shownRunId} companyId={companyId} runId={shownRunId} />
          )}
        </>
      )}

      <PromptVersions companyId={companyId} canPromote={canRun} />
      <CandidateQueue companyId={companyId} canReview={canRun} />
    </div>
  )
}
