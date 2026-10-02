import type { EvalRun, EvalRunsMeta, EvalSuite } from 'api-types'
import { formatAccuracy, formatCost, formatRunDate, SUITE_LABELS } from './format'
import { Card } from '@/components/ui/card'

const SUITES: EvalSuite[] = ['insights', 'policy_extraction', 'agent']

/** One card per suite with its latest completed score (SPEC.md section 12). */
export function Scoreboard({ runs, meta }: { runs: EvalRun[]; meta: EvalRunsMeta }) {
  return (
    <div className="grid gap-3 sm:grid-cols-3">
      {SUITES.map((suite) => {
        const latest = runs.find((run) => run.suite === suite && run.status === 'completed')
        const runnable = meta.runnable_suites.includes(suite)
        const cases = meta.active_cases[suite] ?? 0

        return (
          <Card key={suite} role="region" aria-label={`${SUITE_LABELS[suite]} suite`} className="gap-0">
            <h2 className="text-[12px] font-semibold uppercase tracking-wide text-muted-foreground">{SUITE_LABELS[suite]}</h2>
            {latest ? (
              <>
                <p className="mt-2 text-[28px] font-bold tabular-nums tracking-tight">{formatAccuracy(latest.accuracy)}</p>
                <p className="text-[12px] text-muted-foreground">
                  {latest.passed_count} of {latest.cases_count} cases passed · {latest.model}
                </p>
                <ul aria-label={`${SUITE_LABELS[suite]} scores`} className="mt-1.5 space-y-0.5 text-[12px] text-muted-foreground">
                  {latest.stability !== null && <li>Stability {formatAccuracy(latest.stability)} over {latest.stability_samples} compiles</li>}
                  {latest.judge_score !== null && <li>Judge {latest.judge_score} / 5</li>}
                  {latest.judge_agreement !== null && <li>Judge agrees with hand labels {formatAccuracy(latest.judge_agreement)}</li>}
                  {latest.cost_usd !== null && <li>Cost {formatCost(latest.cost_usd)}</li>}
                </ul>
                <p className="mt-1 text-[12px] text-subtle-foreground">Last run {formatRunDate(latest.finished_at ?? latest.created_at)}</p>
              </>
            ) : (
              <>
                <p className="mt-2 text-[28px] font-bold text-subtle-foreground">—</p>
                <p className="text-[12px] text-muted-foreground">
                  {runnable ? `${cases} cases · not run yet` : 'Not runnable yet — needs its scorer'}
                </p>
              </>
            )}
          </Card>
        )
      })}
    </div>
  )
}
