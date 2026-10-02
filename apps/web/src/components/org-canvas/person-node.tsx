import { Handle, Position, type Node, type NodeProps } from '@xyflow/react'
import type { PersonNodeData } from './org-graph'

function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('')
}

export function PersonNode({ data, selected }: NodeProps<Node<PersonNodeData>>) {
  const { person, departmentName, colorClass } = data

  return (
    <div
      className={`flex w-52 items-center gap-2.5 rounded-md border bg-card px-3 py-2 shadow-sm ${
        selected ? 'border-ring ring-2 ring-ring' : 'border-border'
      }`}
    >
      <Handle type="target" position={Position.Top} className="bg-border-strong!" />
      <div
        className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-[11px] font-semibold ${colorClass}`}
      >
        {initials(person.name)}
      </div>
      <div className="min-w-0">
        <p className="truncate text-[13px] font-medium">{person.name}</p>
        <p className="truncate text-[11.5px] text-muted-foreground">
          {person.title ?? 'No title'}
          {departmentName ? ` · ${departmentName}` : ''}
        </p>
      </div>
      <Handle type="source" position={Position.Bottom} className="bg-border-strong!" />
    </div>
  )
}
