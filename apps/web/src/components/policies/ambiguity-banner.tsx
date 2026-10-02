import type { Ambiguity } from 'api-types'
import { useState } from 'react'

// Rules::AmbiguityResolver — the service SPEC.md section 7 describes for
// turning an answered question into an updated rule version — doesn't exist
// on the backend yet, so choosing an option can't actually resolve anything.
// This still shows the real question/options from the extracted rule, and is
// honest about the gap rather than faking a save.
export function AmbiguityBanner({ ambiguity }: { ambiguity: Ambiguity }) {
  const [resolution, setResolution] = useState<string | null>(null)

  return (
    <div className="rounded border border-warning/40 bg-warning-muted px-3 py-2.5">
      <p className="text-[12.5px] font-medium">{ambiguity.question}</p>
      <div className="mt-2 flex flex-wrap gap-1.5">
        {ambiguity.options.map((option) => (
          <button
            key={option}
            type="button"
            onClick={() => setResolution(option)}
            aria-pressed={resolution === option}
            className="rounded border border-warning/50 bg-card px-2.5 py-1 text-[12px] font-medium hover:bg-warning-muted"
          >
            {option}
          </button>
        ))}
      </div>
      {resolution && (
        <p className="mt-2 text-[12px] text-muted-foreground">
          Selected "{resolution}". Resolving ambiguities isn't wired up in the API yet — this would send the rule,
          question and answer to the LLM and save the result as a new rule version.
        </p>
      )}
    </div>
  )
}
