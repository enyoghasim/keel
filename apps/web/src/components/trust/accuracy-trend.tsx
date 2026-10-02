import type { EvalRun } from 'api-types'
import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { formatAccuracy, formatRunDate } from './format'

/** Accuracy across completed runs of a suite, oldest to newest. */
export function AccuracyTrend({ runs }: { runs: EvalRun[] }) {
  const points = runs
    .filter((run) => run.status === 'completed' && run.accuracy !== null)
    .slice()
    .reverse()
    .map((run) => ({ label: formatRunDate(run.created_at), accuracy: run.accuracy }))

  if (points.length < 2) return null

  return (
    <figure aria-label="Accuracy over time" className="m-0 rounded-lg border border-border bg-card p-4 shadow-xs">
      <figcaption className="mb-2 text-[12px] font-semibold uppercase tracking-wide text-muted-foreground">Accuracy over time</figcaption>
      <ResponsiveContainer width="100%" height={180} initialDimension={{ width: 640, height: 180 }}>
        <LineChart data={points} margin={{ left: 0, right: 16, top: 8 }}>
          <CartesianGrid vertical={false} stroke="var(--border)" />
          <XAxis dataKey="label" tick={{ fontSize: 11 }} stroke="var(--muted-foreground)" />
          <YAxis domain={[0, 1]} tickFormatter={(v: number) => formatAccuracy(v)} tick={{ fontSize: 11 }} width={48} stroke="var(--muted-foreground)" />
          <Tooltip formatter={(v) => formatAccuracy(Number(v))} />
          <Line dataKey="accuracy" name="Accuracy" stroke="var(--chart-1)" strokeWidth={2} dot={{ r: 3 }} />
        </LineChart>
      </ResponsiveContainer>
    </figure>
  )
}
