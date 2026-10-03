import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { EvalChannelEvent, EvalRun, EvalRunWithResults, Envelope } from 'api-types'
import { useCallback, useEffect } from 'react'
import { api } from '../../lib/api'
import { CABLE_POLL_INTERVAL_MS, useCableHealthy, useChannel } from '../../lib/cable'
import { evalRunQueryKey, evalRunsQueryKey, promptVersionsQueryKey } from './eval-query-keys'

/**
 * Follows one in-progress run over EvalChannel and folds each event into
 * the cached run list and run detail, so the scoreboard, list and detail
 * all fill in live without polling. Renders nothing.
 */
export function EvalRunWatcher({ companyId, runId }: { companyId: string; runId: number }) {
  const queryClient = useQueryClient()
  const cableHealthy = useCableHealthy()

  const onEvent = useCallback(
    (event: EvalChannelEvent) => {
      if (event.event === 'run') {
        queryClient.setQueryData<Envelope<EvalRun[]>>(evalRunsQueryKey(companyId), (list) =>
          list && { ...list, data: list.data?.map((run) => (run.id === event.run.id ? event.run : run)) },
        )
        queryClient.setQueryData<Envelope<EvalRunWithResults>>(evalRunQueryKey(companyId, runId), (detail) =>
          detail?.data && { ...detail, data: { ...detail.data, ...event.run } },
        )
        // A detail fetch that raced the first few result events can be
        // missing some of them; once the run is over, reload it whole.
        if (event.run.status === 'completed' || event.run.status === 'failed') {
          queryClient.invalidateQueries({ queryKey: evalRunQueryKey(companyId, runId) })
          // Each prompt version shows its latest completed run and the cases it would regress.
          queryClient.invalidateQueries({ queryKey: promptVersionsQueryKey(companyId) })
        }
      } else {
        queryClient.setQueryData<Envelope<EvalRunWithResults>>(evalRunQueryKey(companyId, runId), (detail) => {
          if (!detail?.data) return detail
          const results = detail.data.results.filter((r) => r.id !== event.result.id)
          const passed = [...results, event.result].filter((r) => r.passed).length
          return {
            ...detail,
            data: { ...detail.data, cases_count: event.total, passed_count: passed, results: [...results, event.result] },
          }
        })
      }
    },
    [queryClient, companyId, runId],
  )

  useChannel<EvalChannelEvent>('EvalChannel', { eval_run_id: runId }, onEvent)

  // While the socket looks unreachable, poll the run's full detail instead
  // of trying to replay EvalChannel's incremental run/result events — a
  // poll already has the complete picture (every result so far), so it
  // replaces the cached detail wholesale rather than merging piecemeal.
  const poll = useQuery({
    queryKey: ['eval_run_poll', companyId, runId],
    queryFn: () => api.get<Envelope<EvalRunWithResults>>(`/companies/${companyId}/eval_runs/${runId}`),
    enabled: !cableHealthy,
    refetchInterval: cableHealthy ? false : CABLE_POLL_INTERVAL_MS,
  })
  useEffect(() => {
    const polled = poll.data
    if (!polled?.data) return
    queryClient.setQueryData<Envelope<EvalRunWithResults>>(evalRunQueryKey(companyId, runId), polled)
    queryClient.setQueryData<Envelope<EvalRun[]>>(evalRunsQueryKey(companyId), (list) =>
      list && { ...list, data: list.data?.map((run) => (run.id === runId ? { ...run, ...polled.data } : run)) },
    )
    if (polled.data.status === 'completed' || polled.data.status === 'failed') {
      queryClient.invalidateQueries({ queryKey: promptVersionsQueryKey(companyId) })
    }
  }, [poll.data, queryClient, companyId, runId])

  return null
}
