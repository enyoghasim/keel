import type { InsightQuery } from 'api-types'
import { describeQuery } from './describe-query'

/** How Keel understood a question, as a row of small chips (SPEC.md section 11). */
export function QueryChips({ query }: { query: InsightQuery }) {
  return (
    <ul aria-label="How Keel understood the question" className="flex flex-wrap gap-1.5">
      {describeQuery(query).map((chip, i) => (
        <li
          key={chip}
          className={
            i === 0
              ? 'rounded-full bg-brand-muted px-2.5 py-0.5 text-[12px] font-medium text-brand-strong'
              : 'rounded-full border border-border bg-card px-2.5 py-0.5 text-[12px] text-muted-foreground'
          }
        >
          {chip}
        </li>
      ))}
    </ul>
  )
}
