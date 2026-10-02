import type { EvalRun, EvalRunStatus } from 'api-types'
import { formatAccuracy, formatRunDate, SUITE_LABELS } from './format'

const STATUS_TONE: Record<EvalRunStatus, string> = {
  pending: 'border-border-strong bg-secondary text-muted-foreground',
  running: 'border-info/40 bg-info-muted text-info',
  completed: 'border-success/40 bg-success-muted text-success',
  failed: 'border-destructive/40 bg-destructive-muted text-destructive',
}

export function RunList({
  runs,
  selectedRunId,
  compareIds,
  onSelect,
  onToggleCompare,
}: {
  runs: EvalRun[]
  selectedRunId: number | null
  compareIds: number[]
  onSelect: (runId: number) => void
  onToggleCompare: (runId: number) => void
}) {
  return (
    <table className="w-full text-[13px]">
      <caption className="sr-only">Eval runs</caption>
      <thead>
        <tr className="border-b border-border text-left text-[12px] text-muted-foreground">
          <th className="w-8 py-1.5 font-medium">
            <span className="sr-only">Compare</span>
          </th>
          <th className="py-1.5 font-medium">Run</th>
          <th className="py-1.5 font-medium">Model</th>
          <th className="py-1.5 font-medium">Status</th>
          <th className="py-1.5 text-right font-medium">Accuracy</th>
        </tr>
      </thead>
      <tbody>
        {runs.map((run) => (
          <tr key={run.id} className={`border-b border-border last:border-0 ${run.id === selectedRunId ? 'bg-secondary' : ''}`}>
            <td className="py-1.5">
              <input
                type="checkbox"
                aria-label={`Compare run #${run.id}`}
                checked={compareIds.includes(run.id)}
                disabled={run.status !== 'completed'}
                onChange={() => onToggleCompare(run.id)}
              />
            </td>
            <td className="py-1.5">
              <button type="button" onClick={() => onSelect(run.id)} className="text-left font-medium hover:underline">
                #{run.id} · {SUITE_LABELS[run.suite]} · {formatRunDate(run.created_at)}
              </button>
            </td>
            <td className="py-1.5 text-muted-foreground">{run.model ?? '—'}</td>
            <td className="py-1.5">
              <span className={`rounded border px-1.5 py-0.5 text-[11px] font-medium ${STATUS_TONE[run.status]}`}>{run.status}</span>
            </td>
            <td className="py-1.5 text-right font-mono tabular-nums">
              {run.status === 'completed' ? `${formatAccuracy(run.accuracy)} (${run.passed_count}/${run.cases_count})` : '—'}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
