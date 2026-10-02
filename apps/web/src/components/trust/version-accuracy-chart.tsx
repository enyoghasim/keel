import type { PromptVersion } from 'api-types'
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { formatAccuracy } from './format'
import { versionAccuracyPoints } from './version-accuracy'

export function VersionAccuracyChart({ versions, promptKey }: { versions: PromptVersion[]; promptKey: string }) {
  const points = versionAccuracyPoints(versions, promptKey)
  if (points.length < 2) return null

  return (
    <figure aria-label={`${promptKey} accuracy by prompt version`} className="m-0">
      <ResponsiveContainer width="100%" height={140} initialDimension={{ width: 480, height: 140 }}>
        <BarChart data={points} margin={{ left: 0, right: 16, top: 8 }}>
          <CartesianGrid vertical={false} stroke="var(--border)" />
          <XAxis dataKey="label" tick={{ fontSize: 11 }} stroke="var(--muted-foreground)" />
          <YAxis domain={[0, 1]} tickFormatter={(v: number) => formatAccuracy(v)} tick={{ fontSize: 11 }} width={48} stroke="var(--muted-foreground)" />
          <Tooltip formatter={(v) => formatAccuracy(Number(v))} />
          <Bar dataKey="accuracy" name="Accuracy" fill="var(--chart-1)" radius={[3, 3, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </figure>
  )
}
