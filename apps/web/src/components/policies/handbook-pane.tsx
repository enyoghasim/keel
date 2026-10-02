import type { Rule } from 'api-types'
import { useEffect, useRef } from 'react'
import { PagePlaceholder } from '../layout/page-placeholder'

// SPEC.md section 7 shows the handbook text with page numbers, but
// Api::RulesController doesn't expose source_chunk_id or page today — only
// the verbatim source_quote survives the hallucination check in
// Assemble::PolicyExtractor. So this pane shows the real quotes and says so,
// rather than inventing page numbers the API doesn't have.
export function HandbookPane({
  rules,
  highlightedRuleId,
}: {
  rules: Rule[]
  highlightedRuleId: number | null
}) {
  const highlightedRef = useRef<HTMLQuoteElement | null>(null)

  useEffect(() => {
    highlightedRef.current?.scrollIntoView?.({ block: 'nearest' })
  }, [highlightedRuleId])

  if (rules.length === 0) {
    return <PagePlaceholder note="No handbook text yet — this policy has no extracted rules." />
  }

  return (
    <div className="space-y-3">
      <p className="text-[12px] text-muted-foreground">
        Handbook excerpts quoted by this policy's rules. Page numbers aren't shown yet — the API doesn't expose
        which page a rule's source chunk came from.
      </p>
      {rules.map((rule) => {
        const highlighted = highlightedRuleId === rule.id
        return (
          <blockquote
            key={rule.id}
            data-testid={`source-quote-${rule.id}`}
            ref={highlighted ? highlightedRef : undefined}
            className={`rounded-lg border px-4 py-3 text-[13px] italic transition-colors ${
              highlighted ? 'border-brand bg-brand-muted' : 'border-border bg-card'
            }`}
          >
            "{rule.source_quote}"
          </blockquote>
        )
      })}
    </div>
  )
}
