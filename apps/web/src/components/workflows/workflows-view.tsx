import { useQuery } from '@tanstack/react-query'
import type { Envelope, Workflow } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { PagePlaceholder } from '../layout/page-placeholder'
import { WorkflowDetail } from './workflow-detail'
import { WorkflowList } from './workflow-list'

export function WorkflowsView({ companyId }: { companyId: string }) {
  const [selectedWorkflowId, setSelectedWorkflowId] = useState<number | null>(null)

  const workflowsQuery = useQuery({
    queryKey: ['workflows', companyId],
    queryFn: () => api.get<Envelope<Workflow[]>>(`/companies/${companyId}/workflows`),
  })

  if (workflowsQuery.isPending) return <PagePlaceholder note="Loading workflows…" />
  if (workflowsQuery.isError) {
    return <PagePlaceholder note={`Couldn't load workflows: ${(workflowsQuery.error as Error).message}`} />
  }

  const workflows = workflowsQuery.data?.data ?? []
  if (workflows.length === 0) {
    return <PagePlaceholder note="No workflows yet. Default workflows are generated during Assemble." />
  }

  const activeWorkflowId = selectedWorkflowId ?? workflows[0].id

  return (
    <div className="space-y-4">
      <WorkflowList workflows={workflows} activeWorkflowId={activeWorkflowId} onSelect={setSelectedWorkflowId} />
      <WorkflowDetail companyId={companyId} workflowId={activeWorkflowId} />
    </div>
  )
}
