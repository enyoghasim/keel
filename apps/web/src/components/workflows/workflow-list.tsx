import type { Workflow, WorkflowStatus } from 'api-types'

const STATUS_LABEL: Record<WorkflowStatus, string> = {
  draft: 'Draft',
  active: 'Active',
  superseded: 'Superseded',
}

const STATUS_TONE: Record<WorkflowStatus, string> = {
  draft: 'border-border-strong bg-secondary text-muted-foreground',
  active: 'border-success/40 bg-success-muted text-success',
  superseded: 'border-border-strong bg-secondary text-subtle-foreground',
}

export function WorkflowList({
  workflows,
  activeWorkflowId,
  onSelect,
}: {
  workflows: Workflow[]
  activeWorkflowId: number
  onSelect: (workflowId: number) => void
}) {
  return (
    <div className="flex flex-wrap gap-2" role="tablist" aria-label="Workflows">
      {workflows.map((workflow) => {
        const active = workflow.id === activeWorkflowId
        return (
          <button
            key={workflow.id}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onSelect(workflow.id)}
            className={`flex items-center gap-2 rounded-lg border px-3 py-1.5 text-[13px] font-medium ${
              active ? 'border-primary bg-primary text-primary-foreground' : 'border-border bg-card hover:bg-secondary'
            }`}
          >
            {workflow.name}
            <span
              className={`rounded border px-1.5 py-0.5 text-[11px] font-medium ${
                active ? 'border-primary-foreground/30' : STATUS_TONE[workflow.status]
              }`}
            >
              {STATUS_LABEL[workflow.status]}
            </span>
          </button>
        )
      })}
    </div>
  )
}
