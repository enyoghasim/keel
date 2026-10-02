import type { InsightQuery } from '../generated/insight-query'

// Mirrors InsightQuery::STATUSES and InsightQuery#as_payload
// (apps/api/app/models/insight_query.rb) — what Api::InsightsController
// renders and InsightChannel broadcasts. Named Insight rather than
// InsightQuery so it doesn't collide with the generated query-object type.
export type InsightStatus = 'pending' | 'answered' | 'needs_clarification' | 'failed'

// Insights::QueryBuilder::METRICS' units.
export type InsightUnit = 'count' | 'days' | 'eur' | 'hours' | 'percent'

// `key` is a record id for department/person/approver/policy groups, the
// raw value for the rest (e.g. "2026-07" for month), and null for a single
// total or a group with no value.
export interface InsightRow {
  key: string | number | null
  label: string
  value: number
}

export interface InsightResult {
  rows: InsightRow[]
  unit: InsightUnit
  summary: string
}

export interface Insight {
  id: number
  person_id: number
  question: string
  status: InsightStatus
  query: InsightQuery | null
  clarification: string | null
  result: InsightResult | null
  error_message: string | null
  created_at: string
}
