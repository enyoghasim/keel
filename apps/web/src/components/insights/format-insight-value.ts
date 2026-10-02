import type { InsightUnit } from 'api-types'

// One formatter per Insights::QueryBuilder unit, shared by the chart axes,
// tooltips and the value table.
export function formatInsightValue(value: number, unit: InsightUnit): string {
  switch (unit) {
    case 'eur':
      return `€${value.toLocaleString('en-GB', { minimumFractionDigits: Number.isInteger(value) ? 0 : 2, maximumFractionDigits: 2 })}`
    case 'days':
      return `${value.toLocaleString('en-GB')} ${value === 1 ? 'day' : 'days'}`
    case 'hours':
      return `${value.toLocaleString('en-GB', { maximumFractionDigits: 1 })} h`
    case 'percent':
      return `${value.toLocaleString('en-GB', { maximumFractionDigits: 1 })}%`
    case 'count':
      return value.toLocaleString('en-GB')
  }
}
