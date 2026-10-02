import { useQuery } from '@tanstack/react-query'
import type { EvalResult, EvalRunWithResults, Envelope } from 'api-types'
import { api } from '../../lib/api'
import { caseQuestion } from './compare-runs'
import { evalRunQueryKey } from './eval-query-keys'
import { describeDiffEntry, describeMetrics, formatAccuracy } from './format'

function json(value: unknown) {
  return JSON.stringify(value, null, 2)
}

function MetricsLine({ result }: { result: EvalResult }) {
  const labels = describeMetrics(result.metrics)
  if (labels.length === 0 && !result.metrics.judge_rationale) return null

  return (
    <div className="space-y-1">
      {labels.length > 0 && <p className="font-mono text-[11.5px] text-muted-foreground">{labels.join(' · ')}</p>}
      {result.metrics.judge_rationale && <p className="text-[12px] text-muted-foreground">Judge: {result.metrics.judge_rationale}</p>}
    </div>
  )
}

/** One case's failure: what was asked, what was expected, what came back, and which fields differed. */
function FailureDrilldown({ result }: { result: EvalResult }) {
  return (
    <div className="mt-2 space-y-2">
      {result.error_message && <p className="text-[12px] text-destructive">{result.error_message}</p>}
      <MetricsLine result={result} />
      {result.diff.length > 0 && (
        <ul aria-label="Fields that differed" className="flex flex-wrap gap-1.5">
          {result.diff.map((entry, index) => (
            <li key={index} className="rounded-full border border-destructive/30 bg-destructive-muted px-2 py-0.5 text-[11px] text-destructive">
              {describeDiffEntry(entry)}
            </li>
          ))}
        </ul>
      )}
      <div className="grid gap-2 md:grid-cols-2">
        <div>
          <p className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">Expected</p>
          <pre className="mt-1 overflow-x-auto rounded bg-secondary p-2 font-mono text-[11.5px]">{json(result.expected)}</pre>
        </div>
        <div>
          <p className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">Actual</p>
          <pre className="mt-1 overflow-x-auto rounded bg-secondary p-2 font-mono text-[11.5px]">{json(result.actual)}</pre>
        </div>
      </div>
    </div>
  )
}

export function RunDetail({ companyId, runId }: { companyId: string; runId: number }) {
  const runQuery = useQuery({
    queryKey: evalRunQueryKey(companyId, runId),
    queryFn: () => api.get<Envelope<EvalRunWithResults>>(`/companies/${companyId}/eval_runs/${runId}`),
  })

  const run = runQuery.data?.data
  if (runQuery.isError) return <p className="text-[13px] text-destructive">{(runQuery.error as Error).message}</p>
  if (!run) return <p className="text-[13px] text-muted-foreground">Loading run…</p>

  const failures = run.results.filter((r) => !r.passed)
  const passes = run.results.filter((r) => r.passed)
  const inProgress = run.status === 'pending' || run.status === 'running'

  return (
    <section aria-label={`Run #${run.id}`} className="rounded-lg border border-border bg-card p-5 shadow-xs">
      <div className="flex items-baseline justify-between gap-4">
        <h2 className="text-[15px] font-semibold">Run #{run.id}</h2>
        <p className="text-[13px] text-muted-foreground">
          {inProgress
            ? `${run.results.length} of ${run.cases_count || '…'} cases scored`
            : `${formatAccuracy(run.accuracy)} · ${run.passed_count} of ${run.cases_count} passed`}
        </p>
      </div>
      {inProgress && (
        <div
          role="progressbar"
          aria-label="Run progress"
          aria-valuemin={0}
          aria-valuemax={run.cases_count || 1}
          aria-valuenow={run.results.length}
          className="mt-3 h-1.5 overflow-hidden rounded-full bg-secondary"
        >
          <div
            className="h-full bg-brand transition-all"
            style={{ width: `${run.cases_count ? (100 * run.results.length) / run.cases_count : 0}%` }}
          />
        </div>
      )}
      {run.status === 'failed' && <p className="mt-3 text-[13px] text-destructive">{run.error_message}</p>}

      {failures.length > 0 && (
        <>
          <h3 className="mt-5 text-[12px] font-semibold uppercase tracking-wide text-destructive">Failed ({failures.length})</h3>
          <ul className="mt-2 divide-y divide-border">
            {failures.map((result) => (
              <li key={result.id} className="py-2">
                <details>
                  <summary className="cursor-pointer text-[13px]">
                    <span className="font-medium">{caseQuestion(result)}</span>
                    <span className="ml-2 font-mono text-[11px] text-subtle-foreground">{result.case_key}</span>
                  </summary>
                  <FailureDrilldown result={result} />
                </details>
              </li>
            ))}
          </ul>
        </>
      )}

      {passes.length > 0 && (
        <>
          <h3 className="mt-5 text-[12px] font-semibold uppercase tracking-wide text-success">Passed ({passes.length})</h3>
          <ul className="mt-2 space-y-1">
            {passes.map((result) => (
              <li key={result.id} className="flex justify-between gap-3 text-[13px]">
                <span>{caseQuestion(result)}</span>
                <span className="font-mono text-[11px] text-subtle-foreground">{result.latency_ms} ms</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  )
}
