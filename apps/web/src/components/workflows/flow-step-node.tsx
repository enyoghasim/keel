import { Handle, Position, type Node, type NodeProps } from '@xyflow/react'
import type { FlowNodeData } from './flow-graph'
import { Badge } from '@/components/ui/badge'

const KIND_LABEL: Record<FlowNodeData['kind'], string> = {
  trigger: 'Trigger',
  approval: 'Approval',
  task: 'Task',
  notify: 'Notify',
}

const KIND_VARIANT: Record<FlowNodeData['kind'], 'secondary' | 'info' | 'success'> = {
  trigger: 'secondary',
  approval: 'info',
  task: 'success',
  notify: 'secondary',
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

export function FlowStepNode({ data }: NodeProps<Node<FlowNodeData>>) {
  const { kind, label, subtitle, runStatus, diffStatus } = data
  const skipped = runStatus === 'skipped'

  return (
    <div
      className={`flex w-54 flex-col gap-1 rounded-md border bg-card px-3 py-2 shadow-sm transition-opacity ${
        runStatus === 'matched' ? 'border-ring ring-2 ring-ring' : ''
      } ${skipped ? 'opacity-40' : ''} ${diffStatus ? DIFF_STYLE[diffStatus] : ''}`}
    >
      {kind !== 'trigger' && <Handle type="target" position={Position.Left} className="bg-border-strong!" />}
      <div className="flex items-center justify-between gap-2">
        <Badge variant={KIND_VARIANT[kind]}>{KIND_LABEL[kind]}</Badge>
        {diffStatus && <span className="text-[11px] font-semibold uppercase tracking-wider">{DIFF_LABEL[diffStatus]}</span>}
      </div>
      <p className={`truncate text-[13px] font-medium ${diffStatus === 'removed' ? 'line-through' : ''}`}>{label}</p>
      {subtitle && <p className="truncate text-[11.5px] text-muted-foreground">{subtitle}</p>}
      <Handle type="source" position={Position.Right} className="bg-border-strong!" />
    </div>
  )
}
