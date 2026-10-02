import type { Workflow, WorkflowStatus } from 'api-types'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'

const STATUS_LABEL: Record<WorkflowStatus, string> = {
  draft: 'Draft',
  active: 'Active',
  superseded: 'Superseded',
}

const STATUS_VARIANT: Record<WorkflowStatus, 'secondary' | 'success' | 'warning'> = {
  draft: 'secondary',
  active: 'success',
  superseded: 'secondary',
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
    <Tabs value={String(activeWorkflowId)} onValueChange={(value) => onSelect(Number(value))}>
      <TabsList aria-label="Workflows">
        {workflows.map((workflow) => (
          <TabsTrigger key={workflow.id} value={String(workflow.id)}>
            {workflow.name}
            <Badge variant={STATUS_VARIANT[workflow.status]}>
              {STATUS_LABEL[workflow.status]}
            </Badge>
          </TabsTrigger>
        ))}
      </TabsList>
    </Tabs>
  )
}
