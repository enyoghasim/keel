import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { AgentRun, Envelope, McpCall } from 'api-types'
import { useCallback, useState } from 'react'
import { api } from '../../lib/api'
import { useChannel } from '../../lib/cable'
import { TraceDrawer } from '../agent/trace-drawer'
import { formatRunDate } from '../trust/format'
import { Badge } from '@/components/ui/badge'
import { Card } from '@/components/ui/card'

const callsKey = (companyId: string) => ['mcp_calls', companyId] as const

// An MCP call has one step and no model on Keel's side, so it fits the
// agent trace drawer as a one-step run — the "same call arriving" the spec's
// closing shot shows (SPEC.md section 13).
function asTrace(call: McpCall): AgentRun {
  return {
    id: call.id,
    conversation_id: '',
    person_id: 0,
    message: `${call.token_name ?? 'An MCP client'} called ${call.tool_name}`,
    status: call.is_error ? 'failed' : 'completed',
    final_text: null,
    total_tokens: 0,
    error_message: null,
    cost_usd: null,
    feedback: null,
    feedback_reason: null,
    proposal_ids: [],
    created_at: call.created_at,
    steps: [{ id: call.id, position: 1, kind: 'tool', tool_name: call.tool_name, input: call.input, output: call.output, latency_ms: call.latency_ms, tokens: null }],
  }
}

/**
 * The tool calls MCP clients made with this person's tokens, newest first,
 * live over Action Cable. Each opens in the trace drawer.
 */
export function McpCallsPanel({ companyId, personId }: { companyId: string; personId: number }) {
  const queryClient = useQueryClient()
  const [openId, setOpenId] = useState<number | null>(null)

  const query = useQuery({
    queryKey: callsKey(companyId),
    queryFn: () => api.get<Envelope<McpCall[]>>(`/companies/${companyId}/mcp_calls`),
  })

  const onArrived = useCallback(() => queryClient.invalidateQueries({ queryKey: callsKey(companyId) }), [queryClient, companyId])
  useChannel<McpCall>('McpCallChannel', { person_id: personId }, onArrived)

  const calls = query.data?.data ?? []
  const open = calls.find((call) => call.id === openId)

  return (
    <Card role="region" aria-label="MCP calls">
      <div>
        <h2 className="text-[15px] font-semibold">MCP calls</h2>
        <p className="mt-1 text-[13px] text-muted-foreground">What outside AI tools have asked Keel with your tokens, as it happens. Open one to see the input and output.</p>
      </div>

      {calls.length === 0 ? (
        <p className="text-[13px] text-muted-foreground">{query.isPending ? 'Loading…' : 'No calls yet. Connect an MCP client with a token above and ask it something.'}</p>
      ) : (
        <ul className="divide-y divide-border">
          {calls.map((call) => (
            <li key={call.id}>
              <button type="button" onClick={() => setOpenId(call.id)} className="flex w-full flex-wrap items-center gap-x-3 gap-y-1 py-2 text-left text-[13px] hover:bg-secondary">
                <span className="font-mono text-[12.5px] font-medium">{call.tool_name}</span>
                {call.is_error && <Badge variant="destructive">Error</Badge>}
                <span className="text-muted-foreground">{call.token_name ?? 'a revoked token'}</span>
                {call.latency_ms !== null && <span className="font-mono text-[11.5px] text-muted-foreground">{`${call.latency_ms} ms`}</span>}
                <span className="ml-auto text-[12px] text-muted-foreground">{formatRunDate(call.created_at)}</span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {open && <TraceDrawer run={asTrace(open)} title="MCP call" onClose={() => setOpenId(null)} />}
    </Card>
  )
}
