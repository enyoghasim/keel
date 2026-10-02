import { useEffect, useState } from 'react'
import { SidebarTrigger } from '@/components/ui/sidebar'
import { AgentTrace } from '../agent/agent-trace'
import { CommandBar } from '../agent/command-bar'
import { useAgentConversation } from '../agent/use-agent-conversation'
import { useCurrentPerson, useSignOut } from '../../lib/auth'
import { getCurrentCompanyId } from '../../lib/current-company'
import { effectiveTheme, initTheme, toggleTheme, type Theme } from '../../lib/theme'
import { BellTraceIcon, ChevronDownIcon, MoonIcon, SearchIcon, SunIcon } from '../icons/nav-icons'

function initials(name: string) {
  return name
    .split(' ')
    .map((word) => word[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function PersonChip({ companyId }: { companyId: string }) {
  const sessionQuery = useCurrentPerson(companyId)
  const signOut = useSignOut(companyId)
  const person = sessionQuery.data?.data
  if (!person) return null

  return (
    <button
      type="button"
      title="Sign out"
      onClick={() => signOut.mutate()}
      className="flex items-center gap-2 rounded border border-border bg-card py-1 pl-1.5 pr-2.5"
    >
      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#52525b] text-[10.5px] font-bold text-white">
        {initials(person.name)}
      </span>
      <span className="hidden flex-col items-start leading-tight sm:flex">
        <span className="text-[12.5px] font-semibold">{person.name}</span>
        <span className="text-[11px] text-muted-foreground">{person.title ?? person.roles[0] ?? 'Member'}</span>
      </span>
      <ChevronDownIcon className="hidden h-3.25 w-3.25 text-muted-foreground sm:block" />
    </button>
  )
}

export function Topbar() {
  const [theme, setTheme] = useState<Theme>(() => effectiveTheme())
  const [commandOpen, setCommandOpen] = useState(false)
  const [traceRunId, setTraceRunId] = useState<number | null>(null)
  const companyId = getCurrentCompanyId()
  const conversation = useAgentConversation(companyId, commandOpen)
  const latestRunId = conversation.runs.at(-1)?.id ?? null

  useEffect(() => {
    initTheme()
  }, [])

  // ⌘K / Ctrl+K opens the command bar from anywhere.
  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        setCommandOpen((open) => !open)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [])

  return (
    <header className="sticky top-0 z-20 flex h-14 items-center gap-3.5 border-b border-border bg-sidebar px-3 md:px-5">
      <SidebarTrigger className="md:hidden" />
      <button
        type="button"
        onClick={() => setCommandOpen(true)}
        className="flex min-w-0 max-w-105 flex-1 items-center gap-2 overflow-hidden whitespace-nowrap rounded border border-border bg-secondary px-2.5 py-1.5 text-[13px] text-muted-foreground"
      >
        <SearchIcon className="h-3.75 w-3.75 shrink-0" />
        Ask Keel or search…
        <kbd className="ml-auto hidden rounded border border-border-strong bg-card px-1.5 py-0.5 font-mono text-[11px] md:block">
          ⌘K
        </kbd>
      </button>

      <div className="ml-auto flex items-center gap-2.5">
        <button
          type="button"
          title="Agent trace"
          disabled={latestRunId === null}
          onClick={() => setTraceRunId(latestRunId)}
          className="grid h-8.5 w-8.5 place-items-center rounded border border-border bg-card text-muted-foreground hover:bg-secondary hover:text-foreground disabled:opacity-40"
        >
          <BellTraceIcon className="h-4 w-4" />
        </button>
        <button
          type="button"
          title="Toggle theme"
          onClick={() => setTheme(toggleTheme())}
          className="grid h-8.5 w-8.5 place-items-center rounded border border-border bg-card text-muted-foreground hover:bg-secondary hover:text-foreground"
        >
          {theme === 'dark' ? <MoonIcon className="h-4 w-4" /> : <SunIcon className="h-4 w-4" />}
        </button>
        {companyId && <PersonChip companyId={companyId} />}
      </div>

      <CommandBar
        open={commandOpen}
        onOpenChange={setCommandOpen}
        companyId={companyId}
        conversation={conversation}
        onShowTrace={(runId) => {
          // The command bar is modal, so the drawer opens once it's closed.
          setCommandOpen(false)
          setTraceRunId(runId)
        }}
      />
      {companyId && traceRunId !== null && (
        <AgentTrace companyId={companyId} runId={traceRunId} onClose={() => setTraceRunId(null)} />
      )}
    </header>
  )
}
