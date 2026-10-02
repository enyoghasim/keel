import { Button } from '@/components/ui/button'

// SPEC.md section 11's four suggested questions, so the page never starts
// with a blank box.
const SUGGESTED_QUESTIONS = [
  'Who is overloaded with approvals this month?',
  'Leave days by department last quarter',
  'How often do managers override the expense policy?',
  'Median time to approve an expense by department',
]

export function SuggestedQuestions({ onAsk, disabled }: { onAsk: (question: string) => void; disabled: boolean }) {
  return (
    <div className="rounded-lg border border-dashed border-border-strong bg-card px-6 py-10 text-center">
      <p className="text-[13px] text-muted-foreground">
        Ask about requests, leave, expenses or approvals. Keel shows how it understood the question before the answer.
      </p>
      <div className="mx-auto mt-4 grid max-w-2xl gap-2 sm:grid-cols-2">
        {SUGGESTED_QUESTIONS.map((question) => (
          <Button
            key={question}
            type="button"
            variant="outline"
            disabled={disabled}
            onClick={() => onAsk(question)}
            className="h-auto justify-start py-2 text-left whitespace-normal hover:border-brand hover:bg-brand-muted"
          >
            {question}
          </Button>
        ))}
      </div>
    </div>
  )
}
