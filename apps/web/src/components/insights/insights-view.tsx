import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, Insight } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { InsightAnswer } from './insight-answer'
import { insightQueryKey } from './insight-query-key'
import { QuestionBox } from './question-box'
import { SuggestedQuestions } from './suggested-questions'

export function InsightsView({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const [activeId, setActiveId] = useState<number | null>(null)

  const recentQuery = useQuery({
    queryKey: ['insights', companyId],
    queryFn: () => api.get<Envelope<Insight[]>>(`/companies/${companyId}/insights`),
  })

  const ask = useMutation({
    mutationFn: (question: string) => api.post<Envelope<Insight>>(`/companies/${companyId}/insights`, { question }),
    onSuccess: (response) => {
      const insight = response.data
      if (!insight) return
      queryClient.setQueryData(insightQueryKey(companyId, insight.id), response)
      queryClient.invalidateQueries({ queryKey: ['insights', companyId] })
      setActiveId(insight.id)
    },
  })

  const recent = recentQuery.data?.data ?? []

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_260px]">
      <div className="min-w-0 space-y-4">
        <QuestionBox onAsk={(question) => ask.mutate(question)} asking={ask.isPending} />
        {ask.isError && <p className="text-[13px] text-destructive">{(ask.error as Error).message}</p>}

        {activeId === null ? (
          <SuggestedQuestions onAsk={(question) => ask.mutate(question)} disabled={ask.isPending} />
        ) : (
          <InsightAnswer key={activeId} companyId={companyId} insightId={activeId} />
        )}
      </div>

      <aside aria-labelledby="recent-questions-heading">
        <h2 id="recent-questions-heading" className="text-[12px] font-semibold uppercase tracking-wide text-muted-foreground">
          Your recent questions
        </h2>
        {recent.length === 0 ? (
          <p className="mt-2 text-[13px] text-subtle-foreground">None yet.</p>
        ) : (
          <ul className="mt-2 space-y-1">
            {recent.map((insight) => (
              <li key={insight.id}>
                <button
                  type="button"
                  onClick={() => setActiveId(insight.id)}
                  aria-current={insight.id === activeId ? 'true' : undefined}
                  className={`w-full rounded px-2 py-1.5 text-left text-[13px] hover:bg-secondary ${
                    insight.id === activeId ? 'bg-secondary font-medium' : ''
                  }`}
                >
                  {insight.question}
                </button>
              </li>
            ))}
          </ul>
        )}
        {activeId !== null && (
          <button
            type="button"
            onClick={() => setActiveId(null)}
            className="mt-3 text-[12px] font-medium text-brand hover:underline"
          >
            Show suggested questions
          </button>
        )}
      </aside>
    </div>
  )
}
