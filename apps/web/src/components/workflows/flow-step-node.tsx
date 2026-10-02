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
      <Badge variant={KIND_VARIANT[kind]}>{KIND_LABEL[kind]}</Badge>
      <p className="truncate text-[13px] font-medium">{label}</p>
      {subtitle && <p className="truncate text-[11.5px] text-muted-foreground">{subtitle}</p>}
      <Handle type="source" position={Position.Right} className="bg-border-strong!" />
    </div>
  )
}
