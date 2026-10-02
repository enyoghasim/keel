import { Handle, Position, type Node, type NodeProps } from '@xyflow/react'
import type { FlowNodeData } from './flow-graph'

const KIND_LABEL: Record<FlowNodeData['kind'], string> = {
  trigger: 'Trigger',
  approval: 'Approval',
  task: 'Task',
  notify: 'Notify',
}

const KIND_COLOR: Record<FlowNodeData['kind'], string> = {
  trigger: 'border-border-strong bg-muted text-foreground',
  approval: 'border-info/40 bg-info-muted text-info',
  task: 'border-success/40 bg-success-muted text-success',
  notify: 'border-border-strong bg-secondary text-subtle-foreground',
}

export function FlowStepNode({ data }: NodeProps<Node<FlowNodeData>>) {
  const { kind, label, subtitle, runStatus } = data
  const skipped = runStatus === 'skipped'

  return (
    <div
      className={`flex w-54 flex-col gap-1 rounded-md border bg-card px-3 py-2 shadow-sm transition-opacity ${
        runStatus === 'matched' ? 'border-ring ring-2 ring-ring' : ''
      } ${skipped ? 'opacity-40' : ''}`}
    >
      {kind !== 'trigger' && <Handle type="target" position={Position.Left} className="bg-border-strong!" />}
      <span className={`inline-flex w-fit items-center rounded border px-1.5 py-0.5 text-[10.5px] font-medium ${KIND_COLOR[kind]}`}>
        {KIND_LABEL[kind]}
      </span>
      <p className="truncate text-[13px] font-medium">{label}</p>
      {subtitle && <p className="truncate text-[11.5px] text-muted-foreground">{subtitle}</p>}
      <Handle type="source" position={Position.Right} className="bg-border-strong!" />
    </div>
  )
}
