import { useQueryClient } from '@tanstack/react-query'
import type { EvalChannelEvent, EvalRun, EvalRunWithResults, Envelope } from 'api-types'
import { useCallback } from 'react'
import { useChannel } from '../../lib/cable'
import { evalRunQueryKey, evalRunsQueryKey } from './eval-query-keys'

/**
 * Follows one in-progress run over EvalChannel and folds each event into
 * the cached run list and run detail, so the scoreboard, list and detail
 * all fill in live without polling. Renders nothing.
 */
export function EvalRunWatcher({ companyId, runId }: { companyId: string; runId: number }) {
  const queryClient = useQueryClient()

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
  return null
}
