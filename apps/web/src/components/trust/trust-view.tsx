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
import { SUITE_LABELS, SUITE_PROMPT_KEYS } from './format'
import { PromptVersions } from './prompt-versions'
import { RunCompare } from './run-compare'
import { RunDetail } from './run-detail'
import { RunList } from './run-list'
import { Scoreboard } from './scoreboard'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Card } from '@/components/ui/card'

// Radix Select can't hold an empty value, so "the active version" gets a sentinel.
const ACTIVE_VERSION = 'active'

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
  const [promptVersionId, setPromptVersionId] = useState(ACTIVE_VERSION)
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
        // Only suites with a prompt (policy extraction, agent) have versions to pick; only extraction compiles to sample.
        ...(SUITE_PROMPT_KEYS[suite] && promptVersionId !== ACTIVE_VERSION ? { prompt_version_id: Number(promptVersionId) } : {}),
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
  const promptKey = SUITE_PROMPT_KEYS[suite]
  const suiteVersions = (versionsQuery.data?.data ?? []).filter((version) => version.key === promptKey)
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
            <div className="w-44 space-y-1">
              <Label htmlFor="eval-suite">Suite</Label>
              <Select
                value={suite}
                onValueChange={(value) => {
                  setSuite(value as EvalSuite)
                  setPromptVersionId(ACTIVE_VERSION)
                }}
              >
                <SelectTrigger id="eval-suite">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {runnableSuites.map((name) => (
                    <SelectItem key={name} value={name}>
                      {SUITE_LABELS[name]}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            {promptKey && (
              <div className="w-40 space-y-1">
                <Label htmlFor="eval-prompt-version">Prompt version</Label>
                <Select value={promptVersionId} onValueChange={setPromptVersionId}>
                  <SelectTrigger id="eval-prompt-version">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value={ACTIVE_VERSION}>Active version</SelectItem>
                    {suiteVersions.map((version) => (
                      <SelectItem key={version.id} value={String(version.id)}>
                        v{version.version}
                        {version.active ? ' (active)' : ''}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
            {suite === 'policy_extraction' && (
              <div className="w-40 space-y-1">
                <Label htmlFor="eval-stability">Stability samples</Label>
                <Select value={String(stabilitySamples)} onValueChange={(value) => setStabilitySamples(Number(value))}>
                  <SelectTrigger id="eval-stability">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="0">Off</SelectItem>
                    <SelectItem value="3">3 compiles</SelectItem>
                    <SelectItem value="5">5 compiles</SelectItem>
                  </SelectContent>
                </Select>
              </div>
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
