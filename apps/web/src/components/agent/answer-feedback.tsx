import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { AgentFeedbackReason, AgentRun, Envelope } from 'api-types'
import { ThumbsDown, ThumbsUp } from 'lucide-react'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { api } from '../../lib/api'
import { agentRunQueryKey } from './use-agent-run'

const REASONS: { value: AgentFeedbackReason; label: string }[] = [
  { value: 'wrong_answer', label: 'Wrong answer' },
  { value: 'wrong_action', label: 'Wrong action' },
  { value: 'unclear', label: 'Unclear' },
  { value: 'other', label: 'Other' },
]

/**
 * Thumbs up/down on a finished answer (SPEC.md section 9's Feedback). A
 * thumbs-down asks what was wrong; the API turns it into a candidate eval
 * case for the Trust page's review queue.
 */
export function AnswerFeedback({ companyId, run }: { companyId: string; run: AgentRun }) {
  const queryClient = useQueryClient()
  const [asking, setAsking] = useState(false)
  const [reason, setReason] = useState<AgentFeedbackReason | null>(null)
  const [note, setNote] = useState('')

  const send = useMutation({
    mutationFn: (body: { rating: 'up' | 'down'; reason?: AgentFeedbackReason; note?: string }) =>
      api.post<Envelope<AgentRun>>(`/companies/${companyId}/agent_runs/${run.id}/feedback`, body),
    onSuccess: (response) => {
      setAsking(false)
      // Fold the rating into the cached run, keeping its live steps.
      queryClient.setQueryData<Envelope<AgentRun>>(agentRunQueryKey(companyId, run.id), (current) =>
        current?.data && response.data ? { ...current, data: { ...current.data, ...response.data, steps: current.data.steps } } : current,
      )
    },
  })

  // What was just sent wins over the run prop, which only catches up once the cache does.
  const feedback = send.data?.data?.feedback ?? run.feedback
  const thanks = feedback === 'down' && !asking

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-1.5">
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label="Good answer"
          aria-pressed={feedback === 'up'}
          disabled={send.isPending}
          onClick={() => {
            setAsking(false)
            send.mutate({ rating: 'up' })
          }}
          className={`size-7 ${feedback === 'up' ? 'bg-secondary text-foreground' : 'text-muted-foreground'}`}
        >
          <ThumbsUp className="h-3.5 w-3.5" />
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label="Bad answer"
          aria-pressed={feedback === 'down'}
          disabled={send.isPending}
          onClick={() => setAsking(true)}
          className={`size-7 ${feedback === 'down' ? 'bg-secondary text-foreground' : 'text-muted-foreground'}`}
        >
          <ThumbsDown className="h-3.5 w-3.5" />
        </Button>
        {thanks && <span className="text-[12px] text-muted-foreground">Thanks — this becomes a test case for the agent.</span>}
        {feedback === 'up' && <span className="text-[12px] text-muted-foreground">Thanks!</span>}
      </div>

      {asking && (
        <form
          className="space-y-2 rounded border border-border bg-secondary p-2.5"
          onSubmit={(event) => {
            event.preventDefault()
            send.mutate({ rating: 'down', ...(reason ? { reason } : {}), ...(note.trim() ? { note: note.trim() } : {}) })
          }}
        >
          <fieldset aria-label="What was wrong?" className="flex flex-wrap gap-x-3 gap-y-1">
            <legend className="mb-1 text-[12px] font-medium">What was wrong?</legend>
            {REASONS.map((option) => (
              <label key={option.value} className="flex items-center gap-1.5 text-[12px]">
                <input type="radio" name="feedback-reason" checked={reason === option.value} onChange={() => setReason(option.value)} />
                {option.label}
              </label>
            ))}
          </fieldset>
          <label className="block text-[12px]">
            <span className="sr-only">Anything else? (optional)</span>
            <input
              value={note}
              onChange={(event) => setNote(event.target.value)}
              // cmdk treats Enter anywhere inside it as "select the highlighted item".
              onKeyDown={(event) => event.key === 'Enter' && event.stopPropagation()}
              placeholder="Anything else? (optional)"
              aria-label="Anything else? (optional)"
              className="w-full rounded border border-border bg-card px-2 py-1 text-[13px]"
            />
          </label>
          <Button type="submit" size="sm" disabled={send.isPending}>
            Send feedback
          </Button>
        </form>
      )}

      {send.isError && <p className="text-[12px] text-destructive">{(send.error as Error).message}</p>}
    </div>
  )
}
