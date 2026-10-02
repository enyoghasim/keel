import type { InsightFilter, InsightQuery } from 'api-types'

// Plain-English labels for an insight-query object (SPEC.md section 11):
// the chips that show how Keel understood a question, so a non-
// deterministic step becomes something a person can check at a glance.

const METRIC_LABELS: Record<InsightQuery['metric'], string> = {
  request_count: 'Request count',
  leave_days: 'Leave days',
  expense_total: 'Expense total',
  approval_load: 'Approval load',
  time_to_decision: 'Time to decision',
  override_rate: 'Override rate',
  auto_approval_rate: 'Auto-approval rate',
}

const FIELD_LABELS: Record<InsightFilter['field'], string> = {
  'request.kind': 'kind',
  'request.decision': 'decision',
  'request.status': 'status',
  'requester.department': 'department',
  'payload.category': 'category',
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

// Parsed by hand rather than via Date so a "2026-07-01" never shifts a day
// with the viewer's timezone.
function parseDate(iso: string) {
  const [year, month, day] = iso.split('-').map(Number)
  return { year, month, day }
}

function daysInMonth(year: number, month: number) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate()
}

function describeTimeRange({ from, to }: { from: string; to: string }) {
  const start = parseDate(from)
  const end = parseDate(to)
  const wholeMonths = start.day === 1 && end.day === daysInMonth(end.year, end.month)

  if (!wholeMonths) {
    return `${start.day} ${MONTHS[start.month - 1]} ${start.year}–${end.day} ${MONTHS[end.month - 1]} ${end.year}`
  }
  if (start.year === end.year && start.month === end.month) return `${MONTHS[start.month - 1]} ${start.year}`
  if (start.year === end.year) return `${MONTHS[start.month - 1]}–${MONTHS[end.month - 1]} ${end.year}`
  return `${MONTHS[start.month - 1]} ${start.year}–${MONTHS[end.month - 1]} ${end.year}`
}

function describeFilter({ field, op, value }: InsightFilter) {
  const values = Array.isArray(value) ? value.join(' or ') : value
  return `${FIELD_LABELS[field]} ${op === 'neq' ? 'is not' : 'is'} ${values}`
}

export function describeQuery(query: InsightQuery): string[] {
  const chips = [METRIC_LABELS[query.metric]]

  if (query.time_range) chips.push(describeTimeRange(query.time_range))
  if (query.group_by) chips.push(`by ${query.group_by}`)
  for (const filter of query.filters ?? []) chips.push(describeFilter(filter))
  if (query.limit) chips.push(`${query.sort === 'asc' ? 'bottom' : 'top'} ${query.limit}`)

  return chips
}
