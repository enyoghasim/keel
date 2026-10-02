import type { InsightQuery, InsightResult } from 'api-types'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { formatInsightValue } from './format-insight-value'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

const COLORS = ['var(--chart-1)', 'var(--chart-2)', 'var(--chart-3)', 'var(--chart-4)', 'var(--chart-5)', 'var(--chart-6)']

const CHART_NAMES: Record<Exclude<InsightQuery['chart'], 'table'>, string> = {
  bar: 'Bar chart',
  line: 'Line chart',
  pie: 'Pie chart',
}

/**
 * Draws Insights::QueryBuilder's rows with the chart the interpreter
 * picked (SPEC.md section 11), and always lists the exact values in a
 * table underneath — a chart is for the shape, the table is for the
 * numbers someone will quote.
 */
export function InsightChart({ result, chart }: { result: InsightResult; chart: InsightQuery['chart'] }) {
  const format = (value: number) => formatInsightValue(value, result.unit)
  const showChart = chart !== 'table' && result.rows.length > 1

  return (
    <div className="space-y-4">
      {showChart && (
        <figure aria-label={CHART_NAMES[chart]} className="m-0">
          <ResponsiveContainer
            width="100%"
            height={chart === 'bar' ? Math.max(160, result.rows.length * 34) : 280}
            initialDimension={{ width: 640, height: 280 }}
          >
            {chart === 'bar' ? (
              <BarChart data={result.rows} layout="vertical" margin={{ left: 8, right: 24 }}>
                <CartesianGrid horizontal={false} stroke="var(--border)" />
                <XAxis type="number" tickFormatter={format} tick={{ fontSize: 12 }} stroke="var(--muted-foreground)" />
                <YAxis type="category" dataKey="label" width={130} tick={{ fontSize: 12 }} stroke="var(--muted-foreground)" />
                <Tooltip formatter={(value) => format(Number(value))} cursor={{ fill: 'var(--secondary)' }} />
                <Bar dataKey="value" name="Value" fill="var(--chart-1)" radius={[0, 3, 3, 0]} />
              </BarChart>
            ) : chart === 'line' ? (
              <LineChart data={result.rows} margin={{ left: 8, right: 24, top: 8 }}>
                <CartesianGrid vertical={false} stroke="var(--border)" />
                <XAxis dataKey="label" tick={{ fontSize: 12 }} stroke="var(--muted-foreground)" />
                <YAxis tickFormatter={format} tick={{ fontSize: 12 }} width={70} stroke="var(--muted-foreground)" />
                <Tooltip formatter={(value) => format(Number(value))} />
                <Line dataKey="value" name="Value" stroke="var(--chart-1)" strokeWidth={2} dot={{ r: 3 }} />
              </LineChart>
            ) : (
              <PieChart>
                <Tooltip formatter={(value) => format(Number(value))} />
                <Pie data={result.rows} dataKey="value" nameKey="label" innerRadius={60} outerRadius={110} paddingAngle={1}>
                  {result.rows.map((row, i) => (
                    <Cell key={String(row.key ?? row.label)} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
              </PieChart>
            )}
          </ResponsiveContainer>
        </figure>
      )}

      <Table>
        <TableHeader>
          <TableRow className="hover:bg-transparent">
            <TableHead>Group</TableHead>
            <TableHead className="text-right">Value</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {result.rows.map((row, i) => (
            <TableRow key={String(row.key ?? row.label)}>
              <TableCell>
                {chart === 'pie' && showChart && (
                  <span
                    aria-hidden="true"
                    className="mr-2 inline-block size-2 rounded-full align-middle"
                    style={{ background: COLORS[i % COLORS.length] }}
                  />
                )}
                {row.label}
              </TableCell>
              <TableCell className="text-right font-mono tabular-nums">{format(row.value)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
