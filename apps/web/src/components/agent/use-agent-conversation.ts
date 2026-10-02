import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { AgentRun, Envelope } from 'api-types'
import { useCallback, useState } from 'react'
import { api } from '../../lib/api'
import { getStoredConversationId, setStoredConversationId } from '../../lib/agent-conversation'
import { agentRunQueryKey } from './use-agent-run'

const recentKey = (companyId: string) => ['agent_runs', companyId, 'recent'] as const
const threadKey = (companyId: string, conversationId: string) => ['agent_runs', companyId, 'thread', conversationId] as const

/** One run per conversation — its latest — newest conversation first. */
export function latestPerConversation(runs: AgentRun[]) {
  const seen = new Set<string>()
  return runs.filter((run) => !seen.has(run.conversation_id) && seen.add(run.conversation_id))
}

/**
 * The command bar's conversation: which thread is open (remembered across
 * refreshes), its runs oldest first, and the person's recent conversations
 * to reopen. Each run keeps its own live cache entry (useAgentRun), seeded
 * here from what the API returned so opening a thread doesn't refetch every
 * run; the channel is the source of truth for anything still working.
 */
export function useAgentConversation(companyId: string | null, enabled: boolean) {
  const queryClient = useQueryClient()
  const [conversationId, setConversationId] = useState<string | null>(() =>
    companyId ? getStoredConversationId(companyId) : null,
  )

  const seed = useCallback(
    (runs: AgentRun[]) => {
      if (!companyId) return
      for (const run of runs) {
        const key = agentRunQueryKey(companyId, run.id)
        if (!queryClient.getQueryData(key)) queryClient.setQueryData(key, { success: true, message: '', data: run })
      }
    },
    [queryClient, companyId],
  )

  const thread = useQuery({
    queryKey: threadKey(companyId ?? '', conversationId ?? ''),
    queryFn: async () => {
      const response = await api.get<Envelope<AgentRun[]>>(`/companies/${companyId}/agent_runs?conversation_id=${conversationId}`)
      const runs = [...(response.data ?? [])].reverse()
      seed(runs)
      return runs
    },
    enabled: Boolean(companyId && conversationId),
    // Only this hook adds to a thread (see `started`), and each run follows
    // itself over AgentChannel — nothing to refetch.
    staleTime: Infinity,
  })

  const recent = useQuery({
    queryKey: recentKey(companyId ?? ''),
    queryFn: async () => {
      const response = await api.get<Envelope<AgentRun[]>>(`/companies/${companyId}/agent_runs`)
      seed(response.data ?? [])
      return response.data ?? []
    },
    enabled: Boolean(companyId && enabled),
  })

  const open = useCallback(
    (id: string | null) => {
      setConversationId(id)
      if (companyId) setStoredConversationId(companyId, id)
    },
    [companyId],
  )

  /** A message was just sent: show it in its thread, starting one if needed. */
  const started = useCallback(
    (run: AgentRun) => {
      if (!companyId) return
      queryClient.setQueryData(agentRunQueryKey(companyId, run.id), { success: true, message: '', data: run })
      queryClient.setQueryData<AgentRun[]>(threadKey(companyId, run.conversation_id), (runs) => [
        ...(runs ?? []).filter((r) => r.id !== run.id),
        run,
      ])
      void queryClient.invalidateQueries({ queryKey: recentKey(companyId) })
      open(run.conversation_id)
    },
    [queryClient, companyId, open],
  )

  const runs = conversationId ? (thread.data ?? []) : []
  return { conversationId, runs, loading: Boolean(conversationId) && thread.isPending, recent: recent.data ?? [], open, started }
}

export type AgentConversation = ReturnType<typeof useAgentConversation>
