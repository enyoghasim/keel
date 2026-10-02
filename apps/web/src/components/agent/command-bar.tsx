import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import type { AgentRun, Envelope } from 'api-types'
import { Command } from 'cmdk'
import { useState } from 'react'
import { api } from '../../lib/api'
import { navGroups } from '../layout/nav-items'
import { agentRunQueryKey, useAgentRun } from './use-agent-run'

function AgentAnswer({
  companyId,
  runId,
  onShowTrace,
  onAskAgain,
}: {
  companyId: string
  runId: number
  onShowTrace: () => void
  onAskAgain: () => void
}) {
  const run = useAgentRun(companyId, runId).data?.data
  if (!run) return <p className="px-4 py-6 text-[13px] text-muted-foreground">Loading…</p>

  const working = run.status === 'pending' || run.status === 'running'
  const toolSteps = run.steps.filter((s) => s.kind === 'tool')

  return (
    <section aria-label="Agent answer" className="space-y-3 px-4 py-4">
      <p className="text-[12px] font-medium text-muted-foreground">{run.message}</p>
      {working && (
        <p role="status" className="text-[13px] text-muted-foreground">
          {toolSteps.length > 0 ? `Working… used ${toolSteps.map((s) => s.tool_name).join(', ')}` : 'Thinking…'}
        </p>
      )}
      {run.status === 'completed' && <p className="whitespace-pre-wrap text-[14px] leading-relaxed">{run.final_text}</p>}
      {run.status === 'failed' && <p className="text-[13px] text-destructive">{run.error_message}</p>}
      <div className="flex gap-2 pt-1">
        <button
          type="button"
          onClick={onShowTrace}
          className="rounded border border-border px-2.5 py-1 text-[12px] font-medium hover:bg-secondary"
        >
          Show trace ({run.steps.length} {run.steps.length === 1 ? 'step' : 'steps'})
        </button>
        <button type="button" onClick={onAskAgain} className="rounded px-2.5 py-1 text-[12px] font-medium text-brand hover:underline">
          Ask something else
        </button>
      </div>
    </section>
  )
}

/**
 * The ⌘K command bar (SPEC.md sections 9 and 14): typing filters quick
 * "go to" actions, and Enter on "Ask Keel" sends the text to the agent,
 * whose answer fills in live. Navigation works without a company; asking
 * needs one.
 */
export function CommandBar({
  open,
  onOpenChange,
  companyId,
  runId,
  onRunStarted,
  onShowTrace,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  companyId: string | null
  runId: number | null
  onRunStarted: (runId: number | null) => void
  onShowTrace: () => void
}) {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [text, setText] = useState('')

  const ask = useMutation({
    mutationFn: (message: string) => api.post<Envelope<AgentRun>>(`/companies/${companyId}/agent_runs`, { message }),
    onSuccess: (response) => {
      const run = response.data
      if (!run || !companyId) return
      queryClient.setQueryData(agentRunQueryKey(companyId, run.id), response)
      setText('')
      onRunStarted(run.id)
    },
  })

  return (
    <Command.Dialog
      open={open}
      onOpenChange={onOpenChange}
      label="Ask Keel"
      overlayClassName="fixed inset-0 z-50 bg-black/40"
      contentClassName="fixed left-1/2 top-[12vh] z-50 w-[calc(100%-32px)] max-w-xl -translate-x-1/2 overflow-hidden rounded-lg border border-border bg-card shadow-lg"
    >
      {companyId && runId !== null ? (
        <AgentAnswer companyId={companyId} runId={runId} onShowTrace={onShowTrace} onAskAgain={() => onRunStarted(null)} />
      ) : (
        <>
          <Command.Input
            value={text}
            onValueChange={setText}
            placeholder={companyId ? 'Ask Keel anything, or jump to a page…' : 'Jump to a page…'}
            className="w-full border-b border-border bg-transparent px-4 py-3 text-[14px] outline-none placeholder:text-muted-foreground"
          />
          <Command.List className="max-h-80 overflow-y-auto p-1.5">
            <Command.Empty className="px-3 py-4 text-[13px] text-muted-foreground">No matching pages.</Command.Empty>
            {companyId && text.trim() !== '' && (
              <Command.Group heading="Agent" className="text-[11px] text-muted-foreground [&_[cmdk-group-heading]]:px-2.5 [&_[cmdk-group-heading]]:py-1.5">
                <Command.Item
                  value={`ask ${text}`}
                  onSelect={() => ask.mutate(text.trim())}
                  disabled={ask.isPending}
                  className="cursor-pointer rounded px-2.5 py-2 text-[13px] text-foreground data-[selected=true]:bg-secondary"
                >
                  {ask.isPending ? 'Asking…' : `Ask Keel: “${text.trim()}”`}
                </Command.Item>
              </Command.Group>
            )}
            {navGroups.map((group) => (
              <Command.Group
                key={group.label}
                heading={`Go to · ${group.label}`}
                className="text-[11px] text-muted-foreground [&_[cmdk-group-heading]]:px-2.5 [&_[cmdk-group-heading]]:py-1.5"
              >
                {group.items.map((item) => (
                  <Command.Item
                    key={item.to}
                    value={`go to ${item.label}`}
                    onSelect={() => {
                      onOpenChange(false)
                      navigate({ to: item.to })
                    }}
                    className="flex cursor-pointer items-center gap-2 rounded px-2.5 py-2 text-[13px] text-foreground data-[selected=true]:bg-secondary"
                  >
                    <item.icon className="h-4 w-4 text-muted-foreground" />
                    {item.label}
                  </Command.Item>
                ))}
              </Command.Group>
            ))}
          </Command.List>
          {ask.isError && <p className="border-t border-border px-4 py-2 text-[12px] text-destructive">{(ask.error as Error).message}</p>}
        </>
      )}
    </Command.Dialog>
  )
}
