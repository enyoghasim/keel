import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { AgentChannelEvent, AgentRun, Envelope } from 'api-types'
import { useCallback } from 'react'
import { api } from '../../lib/api'
import { useChannel } from '../../lib/cable'

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

  const query = useQuery({
    queryKey,
    queryFn: () => api.get<Envelope<AgentRun>>(`/companies/${companyId}/agent_runs/${runId}`),
    // AgentChannel is the source of truth once subscribed (it sends the
    // current state on subscribe), so never refetch over it: a refetch that
    // started before the run finished would land after the channel's update
    // and put a finished run back to "pending".
    staleTime: Infinity,
  })

  const onEvent = useCallback(
    (event: AgentChannelEvent) => {
      queryClient.setQueryData<Envelope<AgentRun>>(agentRunQueryKey(companyId, runId), (current) => {
        if (event.event === 'run') return { success: true, message: '', ...current, data: event.run }
        if (!current?.data) return current
        const steps = current.data.steps.filter((s) => s.id !== event.step.id)
        return { ...current, data: { ...current.data, steps: [...steps, event.step].sort((a, b) => a.position - b.position) } }
      })
    },
    [queryClient, companyId, runId],
  )
  useChannel<AgentChannelEvent>('AgentChannel', { agent_run_id: runId }, onEvent)

  return query
}
