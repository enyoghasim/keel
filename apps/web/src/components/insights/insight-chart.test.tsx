import { render, screen, within } from '@testing-library/react'
import type { InsightResult } from 'api-types'
import { describe, expect, it } from 'vitest'
import { formatInsightValue } from './format-insight-value'
import { InsightChart } from './insight-chart'

const leaveDays: InsightResult = {
  rows: [
    { key: 2, label: 'Sales', value: 8 },
    { key: 1, label: 'Engineering', value: 2.5 },
  ],
  unit: 'days',
  summary: 'Sales is highest with 8 days, out of 2 departments.',
}

describe('InsightChart', () => {
  it('draws the chart it was asked for, with every value also in a table', () => {
    render(<InsightChart result={leaveDays} chart="bar" />)

    expect(screen.getByRole('figure', { name: 'Bar chart' })).toBeInTheDocument()
    const rows = within(screen.getByRole('table')).getAllByRole('row').slice(1)
    expect(rows.map((row) => row.textContent)).toEqual(['Sales8 days', 'Engineering2.5 days'])
  })

  it('shows only the table for a table chart', () => {
    render(<InsightChart result={{ rows: [{ key: null, label: 'Total', value: 3 }], unit: 'count', summary: '' }} chart="table" />)

    expect(screen.queryByRole('figure')).not.toBeInTheDocument()
    expect(screen.getByRole('cell', { name: '3' })).toBeInTheDocument()
  })
})

describe('formatInsightValue', () => {
  it('formats each unit the way an HR manager would say it', () => {
    expect(formatInsightValue(1500.5, 'eur')).toBe('€1,500.50')
    expect(formatInsightValue(1200, 'eur')).toBe('€1,200')
    expect(formatInsightValue(1, 'days')).toBe('1 day')
    expect(formatInsightValue(4.25, 'hours')).toBe('4.3 h')
    expect(formatInsightValue(25, 'percent')).toBe('25%')
    expect(formatInsightValue(1234, 'count')).toBe('1,234')
  })
})
