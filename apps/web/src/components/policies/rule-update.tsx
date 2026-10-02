import type { RuleResolution } from 'api-types'
import { describeRule } from './describe-rule'

// The before-and-after of a rule rewritten from an answer (SPEC.md section 7):
// shown after the fact, since the new version is already saved.
export function RuleUpdate({ resolution }: { resolution: RuleResolution }) {
  if (resolution.status !== 'resolved' || !resolution.after) return null
  const { before, after } = resolution

  return (
    <div className="rounded border border-info/40 bg-info-muted px-3 py-2.5 text-[12.5px]">
      <p className="font-medium">
        Rule {before.key} updated for “{resolution.answer}”
      </p>
      <p className="mt-1.5 text-muted-foreground">Before</p>
      <p className="line-through decoration-muted-foreground/60">{describeRule(before.conditions, before.actions)}</p>
      <p className="mt-1.5 text-muted-foreground">After</p>
      <p>{describeRule(after.conditions, after.actions)}</p>
    </div>
  )
}
