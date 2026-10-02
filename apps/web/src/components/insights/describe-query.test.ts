import type { InsightQuery } from 'api-types'
import { describe, expect, it } from 'vitest'
import { describeQuery } from './describe-query'

describe('describeQuery', () => {
  it('reads SPEC.md section 11\'s example back as "Approval load · Jul–Sep 2026 · by approver"', () => {
    const query: InsightQuery = {
      metric: 'approval_load',
      group_by: 'approver',
      filters: [{ field: 'request.kind', op: 'eq', value: 'expense' }],
      time_range: { from: '2026-07-01', to: '2026-09-30' },
      sort: 'desc',
      limit: 10,
      chart: 'bar',
    }

    expect(describeQuery(query)).toEqual([
      'Approval load',
      'Jul–Sep 2026',
      'by approver',
      'kind is expense',
      'top 10',
    ])
  })

  it('shows a single whole month as just that month', () => {
    expect(describeQuery({ metric: 'leave_days', chart: 'bar', time_range: { from: '2026-08-01', to: '2026-08-31' } })).toEqual([
      'Leave days',
      'Aug 2026',
    ])
  })

  it('shows a range across years, and exact days when it does not line up with whole months', () => {
    expect(
      describeQuery({ metric: 'request_count', chart: 'line', time_range: { from: '2025-11-01', to: '2026-02-28' } }),
    ).toContain('Nov 2025–Feb 2026')
    expect(
      describeQuery({ metric: 'request_count', chart: 'line', time_range: { from: '2026-07-15', to: '2026-08-10' } }),
    ).toContain('15 Jul 2026–10 Aug 2026')
  })

  it('describes neq and in filters, and an ascending limit', () => {
    const query: InsightQuery = {
      metric: 'expense_total',
      group_by: 'category',
      filters: [
        { field: 'requester.department', op: 'neq', value: 'Sales' },
        { field: 'payload.category', op: 'in', value: ['travel', 'meals'] },
      ],
      sort: 'asc',
      limit: 3,
      chart: 'pie',
    }

    expect(describeQuery(query)).toEqual([
      'Expense total',
      'by category',
      'department is not Sales',
      'category is travel or meals',
      'bottom 3',
    ])
  })
})
