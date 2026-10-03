import { Handle, Position, type Node, type NodeProps } from '@xyflow/react'
import { BellIcon, CheckCircle2Icon, ListChecksIcon, ZapIcon } from 'lucide-react'
import type { ComponentType } from 'react'
import type { FlowNodeData } from './flow-graph'

const KIND_LABEL: Record<FlowNodeData['kind'], string> = {
  trigger: 'Trigger',
  approval: 'Approval',
  task: 'Task',
  notify: 'Notify',
}

// Solid, saturated chip per kind (white icon on top) plus a matching left
// accent bar on the card — the colour is what reads at a glance; the text
// label is there for anyone who can't rely on colour alone.
const KIND_CHIP: Record<FlowNodeData['kind'], string> = {
  trigger: 'bg-foreground',
  approval: 'bg-info',
  task: 'bg-success',
  notify: 'bg-brand',
}

const KIND_ACCENT: Record<FlowNodeData['kind'], string> = {
  trigger: 'before:bg-foreground',
  approval: 'before:bg-info',
  task: 'before:bg-success',
  notify: 'before:bg-brand',
}

const KIND_ICON: Record<FlowNodeData['kind'], ComponentType<{ className?: string }>> = {
  trigger: ZapIcon,
  approval: CheckCircle2Icon,
  task: ListChecksIcon,
  notify: BellIcon,
}

// What this step type actually does, since neither is an integration —
// Task is a manual attestation and Notify just logs who should know,
// nothing is sent. See AGENTS.md rule 2: shown, not hidden.
const KIND_CAPTION: Partial<Record<FlowNodeData['kind'], string>> = {
  task: 'Marked done manually',
  notify: 'Logged, not sent',
}

const DIFF_STYLE: Record<NonNullable<FlowNodeData['diffStatus']>, string> = {
  added: 'border-success ring-2 ring-success',
  removed: 'border-destructive ring-2 ring-destructive opacity-70',
  changed: 'border-warning ring-2 ring-warning',
}

const DIFF_LABEL: Record<NonNullable<FlowNodeData['diffStatus']>, string> = {
  added: 'Added',
  removed: 'Removed',
  changed: 'Changed',
}

const HANDLE_CLASS = 'size-2.5! rounded-full! border-2! border-card! bg-border-strong!'

function initials(name: string) {
  return name.split(' ').map((word) => word[0]).slice(0, 2).join('').toUpperCase()
}

export function FlowStepNode({ data }: NodeProps<Node<FlowNodeData>>) {
  const { kind, label, subtitle, resolvedPerson, runStatus, diffStatus } = data
  const skipped = runStatus === 'skipped'
  const Icon = KIND_ICON[kind]
  const caption = KIND_CAPTION[kind]

  return (
    <div
      className={`relative flex w-60 flex-col gap-1.5 rounded-xl border bg-card py-3 pl-4 pr-3.5 shadow-sm transition-[opacity,box-shadow] before:absolute before:inset-y-3 before:left-0 before:w-1 before:rounded-full before:content-[''] hover:shadow-md ${KIND_ACCENT[kind]} ${
        runStatus === 'matched' ? 'border-ring ring-2 ring-ring' : ''
      } ${skipped ? 'opacity-40' : ''} ${diffStatus ? DIFF_STYLE[diffStatus] : ''}`}
    >
      {kind !== 'trigger' && <Handle type="target" position={Position.Left} className={HANDLE_CLASS} />}
      <div className="flex items-center justify-between gap-2">
        <span className={`flex items-center gap-1.5 rounded-full py-0.5 pl-0.5 pr-2 text-[11px] font-medium text-white ${KIND_CHIP[kind]}`}>
          <span className="grid size-4 place-items-center rounded-full bg-white/20">
            <Icon className="size-2.5" />
          </span>
          {KIND_LABEL[kind]}
        </span>
        {diffStatus && <span className="text-[11px] font-semibold uppercase tracking-wider">{DIFF_LABEL[diffStatus]}</span>}
      </div>
      <p className={`truncate text-[13.5px] font-semibold leading-snug ${diffStatus === 'removed' ? 'line-through' : ''}`}>{label}</p>
      {subtitle && resolvedPerson ? (
        <div className="flex items-center gap-1.5">
          <span className="grid size-5 shrink-0 place-items-center rounded-full bg-[#52525b] text-[9px] font-bold text-white">
            {initials(subtitle)}
          </span>
          <p className="truncate text-[11.5px] text-muted-foreground">{subtitle}</p>
        </div>
      ) : (
        subtitle && <p className="truncate text-[11.5px] text-muted-foreground">{subtitle}</p>
      )}
      {caption && <p className="text-[10.5px] text-muted-foreground/70 italic">{caption}</p>}
      <Handle type="source" position={Position.Right} className={HANDLE_CLASS} />
    </div>
  )
}
