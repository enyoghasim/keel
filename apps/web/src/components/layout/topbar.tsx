import { useEffect, useState } from 'react'
import { effectiveTheme, initTheme, toggleTheme, type Theme } from '../../lib/theme'
import { BellTraceIcon, ChevronDownIcon, MoonIcon, SearchIcon, SunIcon } from '../icons/nav-icons'

export function Topbar() {
  const [theme, setTheme] = useState<Theme>(() => effectiveTheme())

  useEffect(() => {
    initTheme()
  }, [])

  return (
    <header className="sticky top-0 z-20 flex h-14 items-center gap-3.5 border-b border-border bg-sidebar px-5">
      <button
        type="button"
        className="flex max-w-105 flex-1 items-center gap-2 rounded border border-border bg-secondary px-2.5 py-1.5 text-[13px] text-muted-foreground"
      >
        <SearchIcon className="h-3.75 w-3.75 shrink-0" />
        Ask Keel or search…
        <kbd className="ml-auto rounded border border-border-strong bg-card px-1.5 py-0.5 font-mono text-[11px]">
          ⌘K
        </kbd>
      </button>

      <div className="ml-auto flex items-center gap-2.5">
        <button
          type="button"
          title="Agent trace"
          className="grid h-8.5 w-8.5 place-items-center rounded border border-border bg-card text-muted-foreground hover:bg-secondary hover:text-foreground"
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
        <button
          type="button"
          className="flex items-center gap-2 rounded border border-border bg-card py-1 pl-1.5 pr-2.5"
        >
          <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#52525b] text-[10.5px] font-bold text-white">
            IC
          </span>
          <span className="flex flex-col items-start leading-tight">
            <span className="text-[12.5px] font-semibold">Ifeoma Chukwu</span>
            <span className="text-[11px] text-muted-foreground">HR Admin</span>
          </span>
          <ChevronDownIcon className="h-3.25 w-3.25 text-muted-foreground" />
        </button>
      </div>
    </header>
  )
}
