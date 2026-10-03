import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { AgentChannelEvent, AgentRun, Envelope } from 'api-types'
import { useCallback } from 'react'
import { api } from '../../lib/api'
import { CABLE_POLL_INTERVAL_MS, useCableHealthy, useChannel } from '../../lib/cable'

export function agentRunQueryKey(companyId: string, runId: number) {
  return ['agent_run', companyId, runId] as const
}

/**
 * One agent run, kept live: loads it once, then folds AgentChannel's
 * events (each step as it's recorded, the run when it finishes) into the
 * cache. Shared by the command bar's answer and the trace drawer, so both
 * show the same run without polling.
 */
export function useAgentRun(companyId: string, runId: number) {
  const queryClient = useQueryClient()
  const queryKey = agentRunQueryKey(companyId, runId)
  const cableHealthy = useCableHealthy()

  const query = useQuery({
    queryKey,
    queryFn: () => api.get<Envelope<AgentRun>>(`/companies/${companyId}/agent_runs/${runId}`),
    // AgentChannel is the source of truth once subscribed (it sends the
    // current state on subscribe), so never refetch over it: a refetch that
    // started before the run finished would land after the channel's update
    // and put a finished run back to "pending". While the socket looks
    // unreachable, poll it instead — a full snapshot replaces the cached
    // run wholesale either way (the "run" branch below), so a poll lands
    // the same as a missed event; only the token-by-token delta streaming
    // is lost, in favour of the answer jumping once the next poll lands.
    staleTime: Infinity,
    refetchInterval: cableHealthy ? false : CABLE_POLL_INTERVAL_MS,
  })

  const onEvent = useCallback(
    (event: AgentChannelEvent) => {
      queryClient.setQueryData<Envelope<AgentRun>>(agentRunQueryKey(companyId, runId), (current) => {
        if (event.event === 'run') return { success: true, message: '', ...current, data: event.run }
        if (!current?.data) return current
        // `text` is the full answer-so-far, not just the new piece — safe to
        // just replace, even if this fires more than once for the same event.
        if (event.event === 'delta') return { ...current, data: { ...current.data, final_text: event.text } }
        const steps = current.data.steps.filter((s) => s.id !== event.step.id)
        return { ...current, data: { ...current.data, steps: [...steps, event.step].sort((a, b) => a.position - b.position) } }
      })
    },
    [queryClient, companyId, runId],
  )
  useChannel<AgentChannelEvent>('AgentChannel', { agent_run_id: runId }, onEvent)

  return query
}

/**
 * Reads the same cached run `useAgentRun` keeps live, without opening a
 * second AgentChannel subscription for it — two listeners on one channel
 * identifier both run the "delta" handler on every event, double-appending
 * streamed text. Only ever reads a cache another `useAgentRun` call (e.g.
 * the matching AgentTurn) is already keeping current.
 */
export function useCachedAgentRun(companyId: string, runId: number) {
  return useQuery({
    queryKey: agentRunQueryKey(companyId, runId),
    queryFn: () => api.get<Envelope<AgentRun>>(`/companies/${companyId}/agent_runs/${runId}`),
    enabled: false,
  })
}
