import type { Ambiguity } from 'api-types'
import { Button } from '@/components/ui/button'

// An open question on a rule (SPEC.md section 7). Choosing an option is a
// person's decision: the page sends it to the API, which has the model rewrite
// the rule and saves it as a new version. While that runs the chosen option
// stays pressed and the others are disabled.
export function AmbiguityBanner({
  ambiguity,
  answering = null,
  error = null,
  onAnswer,
}: {
  ambiguity: Ambiguity
  /** The option being applied right now, if any. */
  answering?: string | null
  error?: string | null
  onAnswer?: (option: string) => void
}) {
  return (
    <div className="rounded border border-warning/40 bg-warning-muted px-3 py-2.5">
      <p className="text-[12.5px] font-medium">{ambiguity.question}</p>
      <div className="mt-2 flex flex-wrap gap-1.5">
        {ambiguity.options.map((option) => (
          <Button
            key={option}
            type="button"
            variant="outline"
            size="sm"
            onClick={() => onAnswer?.(option)}
            disabled={answering !== null}
            aria-pressed={answering === option}
            className="border-warning/50 hover:bg-warning-muted"
          >
            {option}
          </Button>
        ))}
      </div>
      {answering && <p className="mt-2 text-[12px] text-muted-foreground">Updating the rule for “{answering}”…</p>}
      {error && <p className="mt-2 text-[12px] text-destructive">{error}</p>}
    </div>
  )
}
