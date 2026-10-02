import type { EvalRun, EvalRunStatus } from 'api-types'
import { formatAccuracy, formatRunDate, SUITE_LABELS } from './format'
import { Badge } from '@/components/ui/badge'
import { Table, TableBody, TableCaption, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

const STATUS_VARIANT: Record<EvalRunStatus, 'secondary' | 'info' | 'success' | 'destructive'> = {
  pending: 'secondary',
  running: 'info',
  completed: 'success',
  failed: 'destructive',
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
    <Table>
      <TableCaption className="sr-only">Eval runs</TableCaption>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <TableHead className="w-8">
            <span className="sr-only">Compare</span>
          </TableHead>
          <TableHead>Run</TableHead>
          <TableHead>Model</TableHead>
          <TableHead>Status</TableHead>
          <TableHead className="text-right">Accuracy</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {runs.map((run) => (
          <TableRow key={run.id} data-state={run.id === selectedRunId ? 'selected' : undefined}>
            <TableCell>
              <input
                type="checkbox"
                aria-label={`Compare run #${run.id}`}
                checked={compareIds.includes(run.id)}
                disabled={run.status !== 'completed'}
                onChange={() => onToggleCompare(run.id)}
              />
            </TableCell>
            <TableCell>
              <button type="button" onClick={() => onSelect(run.id)} className="text-left font-medium hover:underline">
                #{run.id} · {SUITE_LABELS[run.suite]} · {formatRunDate(run.created_at)}
              </button>
            </TableCell>
            <TableCell className="text-muted-foreground">{run.model ?? '—'}</TableCell>
            <TableCell>
              <Badge variant={STATUS_VARIANT[run.status]}>{run.status}</Badge>
            </TableCell>
            <TableCell className="text-right font-mono tabular-nums">
              {run.status === 'completed' ? `${formatAccuracy(run.accuracy)} (${run.passed_count}/${run.cases_count})` : '—'}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
