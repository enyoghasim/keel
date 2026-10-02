import type { ReactNode } from 'react'

export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string
  subtitle: string
  action?: ReactNode
}) {
  return (
    <div className="mb-6 flex items-start justify-between gap-4">
      <div>
        <h1 className="text-[22px] font-bold tracking-tight">{title}</h1>
        <p className="mt-1 max-w-[56ch] text-[13.5px] text-muted-foreground">{subtitle}</p>
      </div>
      {action}
    </div>
  )
}
