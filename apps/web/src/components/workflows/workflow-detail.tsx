import { useQuery } from '@tanstack/react-query'
import type { Envelope, Person, Workflow, WorkflowTestRunResult } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { useCurrentPerson } from '../../lib/auth'
import { PagePlaceholder } from '../layout/page-placeholder'
import { DescribeChangeBox } from './describe-change-box'
import { FlowCanvas } from './flow-canvas'
import { TestRunDialog } from './test-run-dialog'
import { Button } from '@/components/ui/button'

const OUTCOME_LABEL: Record<WorkflowTestRunResult['outcome'], string> = {
  auto_approve: 'Auto approve',
  require_approval: 'Needs approval',
  reject: 'Reject',
  blocked: 'Blocked',
}

const OUTCOME_TONE: Record<WorkflowTestRunResult['outcome'], string> = {
  auto_approve: 'border-success/40 bg-success-muted text-success',
  require_approval: 'border-info/40 bg-info-muted text-info',
  reject: 'border-destructive/40 bg-destructive-muted text-destructive',
  blocked: 'border-destructive/40 bg-destructive-muted text-destructive',
}

export function WorkflowDetail({ companyId, workflowId }: { companyId: string; workflowId: number }) {
  const canPropose = useCurrentPerson(companyId).data?.data?.roles.includes('hr_admin') ?? false
  const [dialogOpen, setDialogOpen] = useState(false)
  const [testRun, setTestRun] = useState<WorkflowTestRunResult | null>(null)

  const workflowQuery = useQuery({
    queryKey: ['workflow', companyId, workflowId],
    queryFn: () => api.get<Envelope<Workflow>>(`/companies/${companyId}/workflows/${workflowId}`),
  })
  const peopleQuery = useQuery({
    queryKey: ['people', companyId],
    queryFn: () => api.get<Envelope<Person[]>>(`/companies/${companyId}/people`),
  })

  if (workflowQuery.isPending || peopleQuery.isPending) return <PagePlaceholder note="Loading workflow…" />
  if (workflowQuery.isError || peopleQuery.isError) {
    const error = (workflowQuery.error ?? peopleQuery.error) as Error
    return <PagePlaceholder note={`Couldn't load this workflow: ${error.message}`} />
  }

  const workflow = workflowQuery.data?.data
  if (!workflow) return null
  const people = peopleQuery.data?.data ?? []

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-[13px] text-muted-foreground">
          Triggers on every <span className="font-medium text-foreground">{workflow.trigger.request_kind}</span> request.
        </p>
        <Button type="button" onClick={() => setDialogOpen(true)}>
          Test run
        </Button>
      </div>

      {testRun && (
        <div className="flex items-center gap-2 rounded border border-border bg-secondary px-3 py-2">
          <span className={`inline-block rounded border px-1.5 py-0.5 text-[11px] font-medium ${OUTCOME_TONE[testRun.outcome]}`}>
            {OUTCOME_LABEL[testRun.outcome]}
          </span>
          {testRun.errors.map((error) => (
            <span key={error} className="text-[12px] text-destructive">
              {error}
            </span>
          ))}
        </div>
      )}

      {canPropose && <DescribeChangeBox key={workflowId} companyId={companyId} workflowId={workflowId} people={people} />}

      <FlowCanvas workflow={workflow} people={people} testRun={testRun?.steps ?? null} />

      {dialogOpen && (
        <TestRunDialog
          companyId={companyId}
          workflowId={workflowId}
          people={people}
          onClose={() => setDialogOpen(false)}
          onResult={setTestRun}
        />
      )}
    </div>
  )
}
