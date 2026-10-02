import { Link } from '@tanstack/react-router'
import { KeelMark } from '../icons/KeelMark'
import { SettingsIcon } from '../icons/nav-icons'
import { navGroups } from './nav-items'

export function Sidebar() {
  return (
    <nav className="sticky top-0 flex h-screen w-59 shrink-0 flex-col gap-1 border-r border-border bg-sidebar p-3.5">
      <div className="flex items-center gap-2.5 px-2.5 pb-5 pt-1">
        <span className="flex h-6.5 w-6.5 shrink-0 items-center justify-center rounded bg-brand text-brand-foreground">
          <KeelMark className="h-3.75 w-3.75" />
        </span>
        <span className="text-[15px] font-semibold tracking-tight">Keel</span>
      </div>

      {navGroups.map((group) => (
        <div key={group.label}>
          <div className="px-2.5 pb-1.5 pt-3.5 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
            {group.label}
          </div>
          {group.items.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              className="flex w-full items-center gap-2.5 rounded px-2.5 py-2 text-[13.5px] font-medium text-foreground/70 hover:bg-secondary hover:text-foreground"
              activeProps={{
                className: '!bg-sidebar-accent !text-sidebar-accent-foreground font-semibold',
              }}
            >
              <item.icon className="h-4.25 w-4.25 shrink-0" />
              {item.label}
            </Link>
          ))}
        </div>
      ))}

      <div className="mt-auto border-t border-border pt-3">
        <button
          type="button"
          className="flex w-full items-center gap-2.5 rounded px-2.5 py-2 text-[13.5px] font-medium text-foreground/70 hover:bg-secondary hover:text-foreground"
        >
          <SettingsIcon className="h-4.25 w-4.25 shrink-0" />
          Settings
        </button>
      </div>
    </nav>
  )
}
