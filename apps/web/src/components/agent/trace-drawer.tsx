import type { AgentRun, AgentStep } from 'api-types'
import { ChevronRightIcon, XIcon } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Sheet, SheetClose, SheetContent, SheetDescription, SheetTitle } from '@/components/ui/sheet'
import { traceTotals } from './trace-totals'

function stepTitle(step: AgentStep) {
  if (step.kind === 'tool') return step.tool_name ?? 'tool'
  const calls = (step.output?.tool_calls as { name: string }[] | undefined) ?? []
  return calls.length > 0 ? `Model → ${calls.map((c) => c.name).join(', ')}` : 'Model answer'
}

function JsonBlock({ label, value }: { label: string; value: unknown }) {
  return (
    <details className="group mt-1.5">
      <summary className="flex cursor-pointer list-none items-center gap-1 text-[11.5px] text-muted-foreground [&::-webkit-details-marker]:hidden">
        <ChevronRightIcon className="size-3 shrink-0 transition-transform duration-200 ease-out group-open:rotate-90" />
        {label}
      </summary>
      <pre className="mt-1 max-h-64 overflow-auto rounded bg-secondary p-2 font-mono text-[11px]">{JSON.stringify(value, null, 2)}</pre>
    </details>
  )
}

/**
 * An agent run as a vertical timeline (SPEC.md section 9's trace drawer):
 * each model reply and tool call with its input and output as collapsible
 * JSON, latency and tokens, and a totals footer.
 */
export function TraceDrawer({ run, title = 'Agent trace', onClose }: { run: AgentRun; title?: string; onClose: () => void }) {
  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent aria-label={title} showCloseButton={false} className="z-60 w-full gap-0 sm:max-w-md">
        <div className="flex items-start justify-between gap-3 border-b border-border px-4 py-3">
          <div className="min-w-0">
            <SheetTitle className="text-[14px]">{title}</SheetTitle>
            <SheetDescription className="truncate text-[12px]">{run.message}</SheetDescription>
          </div>
          <SheetClose asChild>
            <Button variant="ghost" size="icon" aria-label="Close trace" className="size-7">
              <XIcon />
            </Button>
          </SheetClose>
        </div>

        <ol className="relative flex-1 space-y-3 overflow-y-auto px-4 py-3 before:absolute before:top-3 before:bottom-3 before:left-4 before:w-0.5 before:bg-border before:content-['']">
          {run.steps.map((step) => (
            <li key={step.id} className="relative pl-3">
              <span
                aria-hidden="true"
                className={`absolute -left-0.75 top-1.5 size-2 rounded-full ${step.kind === 'tool' ? 'bg-brand' : 'bg-chart-3'}`}
              />
              <div className="flex flex-wrap items-center gap-1.5">
                <span className="text-[12px] font-semibold uppercase tracking-wide text-muted-foreground">{step.kind === 'tool' ? 'Tool' : 'Model'}</span>
                <span className="font-mono text-[12.5px]">{stepTitle(step)}</span>
                {step.latency_ms !== null && <Badge className="font-mono">{`${step.latency_ms} ms`}</Badge>}
                {step.tokens ? <Badge className="font-mono">{`${step.tokens.toLocaleString('en-GB')} tokens`}</Badge> : null}
              </div>
              {step.kind === 'tool' && <JsonBlock label="Input" value={step.input} />}
              <JsonBlock label="Output" value={step.output} />
            </li>
          ))}
          {(run.status === 'pending' || run.status === 'running') && (
            <li className="pl-3 text-[12px] text-muted-foreground" role="status">
              Working…
            </li>
          )}
        </ol>

        <p className="border-t border-border px-4 py-2.5 font-mono text-[11.5px] text-muted-foreground">{traceTotals(run.steps, run.cost_usd)}</p>
      </SheetContent>
    </Sheet>
  )
}
