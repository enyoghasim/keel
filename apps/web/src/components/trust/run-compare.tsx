import { useQuery } from '@tanstack/react-query'
import type { EvalRunWithResults, Envelope } from 'api-types'
import { api } from '../../lib/api'
import { compareRuns, type FlippedCase } from './compare-runs'
import { evalRunQueryKey } from './eval-query-keys'
import { formatAccuracy } from './format'
import { Card } from '@/components/ui/card'

function useRun(companyId: string, runId: number) {
  return useQuery({
    queryKey: evalRunQueryKey(companyId, runId),
    queryFn: () => api.get<Envelope<EvalRunWithResults>>(`/companies/${companyId}/eval_runs/${runId}`),
  })
}

function FlippedList({ title, cases, tone }: { title: string; cases: FlippedCase[]; tone: string }) {
  return (
    <div>
      <h3 className={`text-[12px] font-semibold uppercase tracking-wide ${tone}`}>
        {title} ({cases.length})
      </h3>
      {cases.length === 0 ? (
        <p className="mt-1 text-[13px] text-subtle-foreground">None.</p>
      ) : (
        <ul className="mt-1 space-y-1">
          {cases.map((c) => (
            <li key={c.caseKey} className="text-[13px]">
              {c.question}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

/** Side-by-side comparison of two runs (SPEC.md section 12): which cases flipped. */
export function RunCompare({ companyId, runIds }: { companyId: string; runIds: [number, number] }) {
  const [olderId, newerId] = [...runIds].sort((a, b) => a - b)
  const older = useRun(companyId, olderId).data?.data
  const newer = useRun(companyId, newerId).data?.data

  if (!older || !newer) return <p className="text-[13px] text-muted-foreground">Loading comparison…</p>

  const comparison = compareRuns(older.results, newer.results)

  return (
    <Card role="region" aria-label="Run comparison" className="gap-0 p-5">
      <h2 className="text-[15px] font-semibold">
        Run #{older.id} ({formatAccuracy(older.accuracy)}) → Run #{newer.id} ({formatAccuracy(newer.accuracy)})
      </h2>
      <p className="mt-1 text-[13px] text-muted-foreground">{comparison.unchanged} cases unchanged.</p>
      <div className="mt-4 grid gap-4 md:grid-cols-2">
        <FlippedList title="Now passing" cases={comparison.fixed} tone="text-success" />
        <FlippedList title="Now failing" cases={comparison.regressed} tone="text-destructive" />
      </div>
    </Card>
  )
}
