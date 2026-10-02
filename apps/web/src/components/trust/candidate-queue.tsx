import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, EvalCase } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { candidateCasesQueryKey } from './eval-query-keys'
import { SUITE_LABELS } from './format'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'

type ToolCall = { name: string }

// What the production signal captured, in a form a reviewer can judge at a glance.
function Observed({ input }: { input: EvalCase['input'] }) {
  const observed = input.observed as { final_text?: string; tool_calls?: ToolCall[] } | undefined
  const message = typeof input.message === 'string' ? input.message : typeof input.question === 'string' ? input.question : null

  return (
    <div className="space-y-1 text-[13px]">
      {message && <p className="font-medium">{message}</p>}
      {observed?.final_text && <p className="text-muted-foreground">Answered: {observed.final_text}</p>}
      {observed?.tool_calls && observed.tool_calls.length > 0 && (
        <p className="font-mono text-[11.5px] text-muted-foreground">Tools: {observed.tool_calls.map((call) => call.name).join(', ')}</p>
      )}
    </div>
  )
}

function CandidateRow({ companyId, eval_case, canReview }: { companyId: string; eval_case: EvalCase; canReview: boolean }) {
  const queryClient = useQueryClient()
  const [expected, setExpected] = useState(JSON.stringify(eval_case.expected, null, 2))
  const [parseError, setParseError] = useState<string | null>(null)

  const update = useMutation({
    mutationFn: (body: Record<string, unknown>) => api.patch<Envelope<EvalCase>>(`/companies/${companyId}/eval_cases/${eval_case.id}`, body),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: candidateCasesQueryKey(companyId) }),
  })

  const addToSuite = () => {
    try {
      const parsed = JSON.parse(expected)
      setParseError(null)
      update.mutate({ status: 'active', expected: parsed })
    } catch {
      setParseError("The expected outcome isn't valid JSON.")
    }
  }

  return (
    <li aria-label={eval_case.key} className="space-y-2 py-3">
      <div className="flex flex-wrap items-center gap-2">
        <Badge variant="info">{SUITE_LABELS[eval_case.suite]}</Badge>
        <span className="font-mono text-[11.5px] text-subtle-foreground">{eval_case.key}</span>
      </div>
      <Observed input={eval_case.input} />
      {eval_case.notes && <p className="text-[12px] text-muted-foreground">{eval_case.notes}</p>}

      {canReview && (
        <>
          <label className="block text-[12px] font-medium">
            Expected outcome (JSON)
            <textarea
              value={expected}
              onChange={(event) => setExpected(event.target.value)}
              rows={4}
              spellCheck={false}
              className="mt-1 block w-full rounded border border-border bg-card p-2 font-mono text-[11.5px]"
            />
          </label>
          <div className="flex items-center gap-2">
            <Button type="button" size="sm" onClick={addToSuite} disabled={update.isPending}>
              Add to suite
            </Button>
            <Button type="button" size="sm" variant="outline" onClick={() => update.mutate({ status: 'archived' })} disabled={update.isPending}>
              Archive
            </Button>
          </div>
        </>
      )}
      {parseError && <p className="text-[12px] text-destructive">{parseError}</p>}
      {update.isError && <p className="text-[12px] text-destructive">{(update.error as Error).message}</p>}
    </li>
  )
}

/**
 * The review queue of the production feedback loop (SPEC.md section 12):
 * a thumbs-down or a rejected proposal creates a candidate eval case; a
 * reviewer fills in the expected outcome the signal can't know and adds it
 * to its suite, so the next eval run includes it.
 */
export function CandidateQueue({ companyId, canReview }: { companyId: string; canReview: boolean }) {
  const query = useQuery({
    queryKey: candidateCasesQueryKey(companyId),
    queryFn: () => api.get<Envelope<EvalCase[]>>(`/companies/${companyId}/eval_cases?status=candidate`),
  })

  const cases = query.data?.data ?? []
  if (query.isError) return <p className="text-[13px] text-destructive">{(query.error as Error).message}</p>

  return (
    <Card role="region" aria-label="Candidate cases">
      <h2 className="text-[12px] font-semibold uppercase tracking-wide text-muted-foreground">Candidate cases</h2>
      {cases.length === 0 ? (
        <p className="text-[13px] text-muted-foreground">
          No candidates waiting. A thumbs-down on an agent answer, or a rejected agent proposal, shows up here for review.
        </p>
      ) : (
        <ul className="divide-y divide-border">
          {cases.map((eval_case) => (
            <CandidateRow key={eval_case.id} companyId={companyId} eval_case={eval_case} canReview={canReview} />
          ))}
        </ul>
      )}
    </Card>
  )
}
