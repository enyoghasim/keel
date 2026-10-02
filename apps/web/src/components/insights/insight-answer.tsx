import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, Insight } from 'api-types'
import { useCallback } from 'react'
import { api } from '../../lib/api'
import { useChannel } from '../../lib/cable'
import { InsightChart } from './insight-chart'
import { insightQueryKey } from './insight-query-key'
import { QueryChips } from './query-chips'

/**
 * One question's answer. Starts from GET .../insights/:id and then follows
 * InsightChannel, which sends the current state on subscribe and the final
 * one once InsightJob is done — no polling.
 */
export function InsightAnswer({ companyId, insightId }: { companyId: string; insightId: number }) {
  const queryClient = useQueryClient()
  const queryKey = insightQueryKey(companyId, insightId)

  const insightQuery = useQuery({
    queryKey,
    queryFn: () => api.get<Envelope<Insight>>(`/companies/${companyId}/insights/${insightId}`),
    // InsightChannel sends the current state on subscribe, so a cached
    // answer never needs refetching — and a refetch racing the channel
    // could land late and put an answered question back to "pending".
    staleTime: Infinity,
  })

  const onEvent = useCallback(
    (insight: Insight) => {
      queryClient.setQueryData<Envelope<Insight>>(insightQueryKey(companyId, insight.id), { success: true, message: '', data: insight })
      if (insight.status !== 'pending') queryClient.invalidateQueries({ queryKey: ['insights', companyId] })
    },
    [queryClient, companyId],
  )
  useChannel<Insight>('InsightChannel', { insight_query_id: insightId }, onEvent)

  const insight = insightQuery.data?.data

  if (insightQuery.isError) {
    return <AnswerCard>{`Couldn't load this question: ${(insightQuery.error as Error).message}`}</AnswerCard>
  }
  if (!insight) return <AnswerCard>Loading…</AnswerCard>

  return (
    <section aria-label="Answer" className="rounded-lg border border-border bg-card p-5 shadow-xs">
      <h2 className="text-[15px] font-semibold">{insight.question}</h2>

      {insight.status === 'pending' && (
        <div className="mt-4 space-y-2" role="status">
          <p className="text-[13px] text-muted-foreground">Working out how to answer that…</p>
          <div className="h-3 w-2/3 animate-pulse rounded bg-secondary" />
          <div className="h-32 animate-pulse rounded bg-secondary" />
        </div>
      )}

      {insight.query && (
        <div className="mt-3">
          <QueryChips query={insight.query} />
        </div>
      )}

      {insight.status === 'answered' && insight.result && insight.query && (
        <div className="mt-4 space-y-4">
          <p className="text-[14px]">{insight.result.summary}</p>
          {insight.result.rows.length > 0 && <InsightChart result={insight.result} chart={insight.query.chart} />}
        </div>
      )}

      {insight.status === 'needs_clarification' && (
        <div className="mt-4 rounded-lg border border-info/30 bg-info-muted px-4 py-3 text-[13px]">
          <p className="font-medium text-info">Keel needs a bit more detail</p>
          <p className="mt-1">{insight.clarification}</p>
          <p className="mt-2 text-muted-foreground">Ask again above with the detail added.</p>
        </div>
      )}

      {insight.status === 'failed' && (
        <p className="mt-4 rounded-lg border border-destructive/30 bg-destructive-muted px-4 py-3 text-[13px] text-destructive">
          {insight.error_message}
        </p>
      )}
    </section>
  )
}

function AnswerCard({ children }: { children: string }) {
  return <div className="rounded-lg border border-border bg-card p-5 text-[13px] text-muted-foreground">{children}</div>
}
