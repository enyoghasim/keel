import { useMutation } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import type { AgentRun, Envelope } from 'api-types'
import { Command } from 'cmdk'
import { useEffect, useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { api } from '../../lib/api'
import { navGroups } from '../layout/nav-items'
import { latestPerConversation, type AgentConversation } from './use-agent-conversation'
import { useAgentRun } from './use-agent-run'

const groupClass = 'text-[11px] text-muted-foreground [&_[cmdk-group-heading]]:px-2.5 [&_[cmdk-group-heading]]:py-1.5'

function AgentTurn({ companyId, runId, onShowTrace }: { companyId: string; runId: number; onShowTrace: (runId: number) => void }) {
  const run = useAgentRun(companyId, runId).data?.data
  if (!run) return <p className="px-4 py-6 text-[13px] text-muted-foreground">Loading…</p>

  const working = run.status === 'pending' || run.status === 'running'
  const toolSteps = run.steps.filter((s) => s.kind === 'tool')

  return (
    <section aria-label="Agent answer" className="space-y-2 px-4 py-3">
      <p className="text-[12px] font-medium text-muted-foreground">{run.message}</p>
      {working && (
        <p role="status" className="text-[13px] text-muted-foreground">
          {toolSteps.length > 0 ? `Working… used ${toolSteps.map((s) => s.tool_name).join(', ')}` : 'Thinking…'}
        </p>
      )}
      {run.status === 'completed' && <p className="whitespace-pre-wrap text-[14px] leading-relaxed">{run.final_text}</p>}
      {run.status === 'failed' && <p className="text-[13px] text-destructive">{run.error_message}</p>}
      <Button type="button" variant="outline" size="sm" onClick={() => onShowTrace(run.id)}>
        Show trace ({run.steps.length} {run.steps.length === 1 ? 'step' : 'steps'})
      </Button>
    </section>
  )
}

/** An open conversation: every turn, then a follow-up box that continues it. */
function Thread({
  companyId,
  runs,
  sending,
  onSend,
  onShowTrace,
  onNewConversation,
}: {
  companyId: string
  runs: AgentRun[]
  sending: boolean
  onSend: (message: string) => void
  onShowTrace: (runId: number) => void
  onNewConversation: () => void
}) {
  const [text, setText] = useState('')
  const latest = runs.at(-1)
  const latestRun = useAgentRun(companyId, latest?.id ?? 0).data?.data
  const working = latestRun ? latestRun.status === 'pending' || latestRun.status === 'running' : false
  const bottom = useRef<HTMLDivElement>(null)

  useEffect(() => {
    bottom.current?.scrollIntoView?.({ block: 'end' })
  }, [runs.length, latestRun?.status])

  return (
    <div>
      <div className="max-h-[50vh] divide-y divide-border overflow-y-auto">
        {runs.map((run) => (
          <AgentTurn key={run.id} companyId={companyId} runId={run.id} onShowTrace={onShowTrace} />
        ))}
        <div ref={bottom} />
      </div>
      <form
        className="flex items-center gap-2 border-t border-border p-2.5"
        onSubmit={(event) => {
          event.preventDefault()
          if (!text.trim() || working || sending) return
          onSend(text.trim())
          setText('')
        }}
      >
        <input
          aria-label="Ask a follow-up"
          value={text}
          onChange={(event) => setText(event.target.value)}
          // cmdk treats Enter anywhere inside it as "select the highlighted item".
          onKeyDown={(event) => event.key === 'Enter' && event.stopPropagation()}
          placeholder={working ? 'Waiting for the answer…' : 'Ask a follow-up…'}
          disabled={working}
          autoFocus
          className="min-w-0 flex-1 bg-transparent px-1.5 py-1 text-[14px] outline-none placeholder:text-muted-foreground disabled:opacity-60"
        />
        <Button type="button" variant="link" size="sm" onClick={onNewConversation} className="shrink-0">
          New conversation
        </Button>
      </form>
    </div>
  )
}

/**
 * The ⌘K command bar (SPEC.md sections 9 and 14): typing filters quick
 * "go to" actions and the person's recent conversations, and Enter on
 * "Ask Keel" sends the text to the agent, whose answer fills in live. Once
 * a conversation is open the bar shows its thread and follow-ups continue
 * it. Navigation works without a company; asking needs one.
 */
export function CommandBar({
  open,
  onOpenChange,
  companyId,
  conversation,
  onShowTrace,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  companyId: string | null
  conversation: AgentConversation
  onShowTrace: (runId: number) => void
}) {
  const navigate = useNavigate()
  const [text, setText] = useState('')

  const ask = useMutation({
    mutationFn: (message: string) =>
      api.post<Envelope<AgentRun>>(`/companies/${companyId}/agent_runs`, {
        message,
        ...(conversation.conversationId ? { conversation_id: conversation.conversationId } : {}),
      }),
    onSuccess: (response) => {
      if (!response.data) return
      setText('')
      conversation.started(response.data)
    },
  })

  const recent = latestPerConversation(conversation.recent).slice(0, 5)
  const inThread = companyId && conversation.conversationId !== null

  return (
    <Command.Dialog
      open={open}
      onOpenChange={onOpenChange}
      label="Ask Keel"
      overlayClassName="fixed inset-0 z-50 bg-black/40"
      contentClassName="fixed left-1/2 top-[12vh] z-50 w-[calc(100%-32px)] max-w-xl -translate-x-1/2 overflow-hidden rounded-lg border border-border bg-card shadow-lg"
    >
      {inThread ? (
        conversation.loading ? (
          <p className="px-4 py-6 text-[13px] text-muted-foreground">Loading…</p>
        ) : (
          <>
            <Thread
              companyId={companyId}
              runs={conversation.runs}
              sending={ask.isPending}
              onSend={(message) => ask.mutate(message)}
              onShowTrace={onShowTrace}
              onNewConversation={() => conversation.open(null)}
            />
            {ask.isError && <p className="border-t border-border px-4 py-2 text-[12px] text-destructive">{(ask.error as Error).message}</p>}
          </>
        )
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
              <Command.Group heading="Agent" className={groupClass}>
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
            {companyId && recent.length > 0 && (
              <Command.Group heading="Recent" className={groupClass}>
                {recent.map((run) => (
                  <Command.Item
                    key={run.conversation_id}
                    value={`recent ${run.message} ${run.id}`}
                    onSelect={() => conversation.open(run.conversation_id)}
                    className="cursor-pointer truncate rounded px-2.5 py-2 text-[13px] text-foreground data-[selected=true]:bg-secondary"
                  >
                    {run.message}
                  </Command.Item>
                ))}
              </Command.Group>
            )}
            {navGroups.map((group) => (
              <Command.Group key={group.label} heading={`Go to · ${group.label}`} className={groupClass}>
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
