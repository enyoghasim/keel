import type { Action, Condition } from 'api-types'

const FIELD_LABELS: Record<string, string> = {
  'requester.department': 'department',
  'requester.location': 'location',
  'requester.tenure_months': 'tenure',
  'payload.amount_eur': 'amount',
  'payload.category': 'category',
  'payload.days': 'days',
  'payload.notice_days': 'notice',
}

const OP_LABELS: Record<string, string> = {
  eq: 'is',
  neq: 'is not',
  gt: '>',
  gte: '≥',
  lt: '<',
  lte: '≤',
  in: 'is one of',
  not_in: 'is not one of',
  between: 'is between',
}

function formatValue(field: string, value: unknown): string {
  if (field === 'payload.amount_eur' && typeof value === 'number') return `€${value.toLocaleString('en-US')}`
  if (field === 'requester.tenure_months' && typeof value === 'number') return `${value} months`
  return String(value)
}

function describeLeaf(node: { field: string; op: string; value: unknown }): string {
  const field = FIELD_LABELS[node.field] ?? node.field

  if (node.op === 'between') {
    const [from, to] = node.value as [unknown, unknown]
    return `${field} is between ${formatValue(node.field, from)} and ${formatValue(node.field, to)}`
  }

  if (node.op === 'in' || node.op === 'not_in') {
    const values = (node.value as unknown[]).map((v) => formatValue(node.field, v)).join(', ')
    return `${field} ${OP_LABELS[node.op]} ${values}`
  }

  return `${field} ${OP_LABELS[node.op] ?? node.op} ${formatValue(node.field, node.value)}`
}

function describeCondition(node: Condition): string {
  if ('all' in node) return node.all.map(describeTerm).join(' and ')
  if ('any' in node) return node.any.map(describeTerm).join(' or ')
  return describeLeaf(node)
}

// A compound child nested inside the other boolean kind needs parentheses
// to keep "A and (B or C)" unambiguous from "A and B or C".
function describeTerm(node: Condition): string {
  if ('all' in node || 'any' in node) return `(${describeCondition(node)})`
  return describeLeaf(node)
}

function describeApprover(reference: string): string {
  if (reference === 'manager_of(requester)') return "the requester's manager"

  const roleMatch = reference.match(/^role:(.+)$/)
  if (roleMatch) return `anyone with the ${roleMatch[1]} role`

  return reference
}

function describeAction(action: Action): string {
  switch (action.decision) {
    case 'auto_approve':
      return 'auto-approve'
    case 'reject':
      return `reject (${action.reason})`
    case 'require_approval':
      return `send to ${action.approvers.map(describeApprover).join(', ')} for approval`
  }
}

// Plain-English rendering of a rule's conditions and action (SPEC.md section 7),
// e.g. "If department is Engineering and category is conference and amount ≤
// €1,000 → auto-approve".
export function describeRule(conditions: Condition, actions: Action): string {
  return `If ${describeCondition(conditions)} → ${describeAction(actions)}`
}
