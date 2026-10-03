import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, Integration, Person, Workflow, WorkflowEdit, WorkflowStep, WorkflowStepType } from 'api-types'
import { useCallback, useState } from 'react'
import { api } from '../../lib/api'
import { EditWatcher, ProposedChange } from './describe-change-box'
import { REFERENCE, StepEditPanel } from './step-edit-panel'
import { WorkflowEditorToolbar } from './workflow-editor-toolbar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'

const integrationsKey = (companyId: string) => ['integrations', companyId] as const

function newStep(type: WorkflowStepType): WorkflowStep {
  return { key: `${type}_${Date.now()}`, type, assignee: '' }
}

const STEP_BADGE: Record<WorkflowStepType, 'secondary' | 'success' | 'brand'> = {
  approval: 'secondary',
  task: 'success',
  notify: 'brand',
}

/**
 * Direct, visual editing of a workflow's steps (SPEC.md section 8's
 * editor) — add, remove, reorder and configure task/notify steps. Approval
 * steps are never listed here; they're policy-owned (AGENTS.md rule 2).
 * Still linear, matching Workflows::Runtime: reorder is up/down within one
 * sequence, not a free-form graph.
 *
 * Saving branches on the workflow's status: a draft saves straight away
 * (nothing live is protected yet — see WorkflowPublishBar), an active
 * workflow's edit goes through the same workflow_edits → Change Proposal
 * pipeline DescribeChangeBox's "describe a change" already uses, just fed
 * by these steps instead of an instruction — both land on the same
 * ProposedChange review UI.
 */
export function WorkflowEditor({ companyId, workflow, people }: { companyId: string; workflow: Workflow; people: Person[] }) {
  const queryClient = useQueryClient()
  const [isEditing, setIsEditing] = useState(false)
  const [steps, setSteps] = useState<WorkflowStep[]>(workflow.steps)
  const [openStepKey, setOpenStepKey] = useState<string | null>(null)
  const [edit, setEdit] = useState<WorkflowEdit | null>(null)

  const integrationsQuery = useQuery({
    queryKey: integrationsKey(companyId),
    queryFn: () => api.get<Envelope<Integration[]>>(`/companies/${companyId}/integrations`),
    enabled: isEditing,
  })

  const saveDraft = useMutation({
    mutationFn: () => api.patch<Envelope<Workflow>>(`/companies/${companyId}/workflows/${workflow.id}`, { steps }),
    onSuccess: () => {
      setIsEditing(false)
      void queryClient.invalidateQueries({ queryKey: ['workflow', companyId, workflow.id] })
      void queryClient.invalidateQueries({ queryKey: ['workflows', companyId] })
    },
  })

  const proposeActive = useMutation({
    mutationFn: () => api.post<Envelope<WorkflowEdit>>(`/companies/${companyId}/workflows/${workflow.id}/edits`, { steps }),
    onSuccess: (response) => setEdit(response.data ?? null),
  })

  const onEditEvent = useCallback((event: WorkflowEdit) => setEdit(event), [])
  const drafting = proposeActive.isPending || edit?.status === 'pending'
  const openStep = steps.find((step) => step.key === openStepKey) ?? null

  function startEditing() {
    setSteps(workflow.steps)
    setEdit(null)
    setIsEditing(true)
  }

  function updateStep(updated: WorkflowStep) {
    setSteps((current) => current.map((step) => (step.key === updated.key ? updated : step)))
  }

  function deleteStep(key: string) {
    setSteps((current) => current.filter((step) => step.key !== key))
    setOpenStepKey(null)
  }

  // Reorders among task/notify steps only: approval stays exactly where it
  // is, in both position and content, so a step can never swap past it.
  // Swapping by raw array index would let the last editable step before an
  // approval jump ahead of it — approval is policy-owned, not something an
  // edit here should ever displace.
  function move(key: string, direction: -1 | 1) {
    setSteps((current) => {
      const editableIndices = current.flatMap((step, index) => (step.type === 'approval' ? [] : [ index ]))
      const position = editableIndices.findIndex((index) => current[index].key === key)
      const targetPosition = position + direction
      if (position < 0 || targetPosition < 0 || targetPosition >= editableIndices.length) return current

      const next = [ ...current ]
      const a = editableIndices[position]
      const b = editableIndices[targetPosition]
      ;[ next[a], next[b] ] = [ next[b], next[a] ]
      return next
    })
  }

  const editableKeys = steps.filter((step) => step.type !== 'approval').map((step) => step.key)
  const hasInvalidAssignee = steps.some((step) => step.type !== 'approval' && !REFERENCE.test(step.assignee ?? ''))

  if (!isEditing) {
    return (
      <Button type="button" variant="outline" size="sm" onClick={startEditing}>
        Edit steps
      </Button>
    )
  }

  return (
    <div className="space-y-3 rounded-lg border border-border bg-card p-3">
      <div className="flex items-center justify-between">
        <p className="text-[13px] font-medium">Editing steps</p>
        <WorkflowEditorToolbar
          onAdd={(type) => {
            const step = newStep(type)
            setSteps((current) => [ ...current, step ])
            setOpenStepKey(step.key)
          }}
        />
      </div>

      <ul className="divide-y divide-border">
        {steps.map((step) => (
          <li key={step.key} className="flex items-center justify-between gap-2 py-2">
            <div className="flex min-w-0 items-center gap-2">
              <Badge variant={STEP_BADGE[step.type]}>{step.type}</Badge>
              <span className="truncate text-[13px]">{step.title || step.key}</span>
            </div>
            {step.type !== 'approval' && (
              <div className="flex shrink-0 items-center gap-1">
                <button
                  type="button"
                  aria-label={`Move ${step.title || step.key} up`}
                  disabled={editableKeys.indexOf(step.key) === 0}
                  onClick={() => move(step.key, -1)}
                  className="rounded px-1.5 py-1 text-muted-foreground hover:bg-secondary disabled:opacity-30"
                >
                  ↑
                </button>
                <button
                  type="button"
                  aria-label={`Move ${step.title || step.key} down`}
                  disabled={editableKeys.indexOf(step.key) === editableKeys.length - 1}
                  onClick={() => move(step.key, 1)}
                  className="rounded px-1.5 py-1 text-muted-foreground hover:bg-secondary disabled:opacity-30"
                >
                  ↓
                </button>
                <Button type="button" variant="outline" size="sm" onClick={() => setOpenStepKey(step.key)}>
                  Edit
                </Button>
              </div>
            )}
          </li>
        ))}
      </ul>

      <div className="flex items-center gap-2">
        <Button
          type="button"
          size="sm"
          disabled={saveDraft.isPending || drafting || hasInvalidAssignee}
          onClick={() => (workflow.status === 'draft' ? saveDraft.mutate() : proposeActive.mutate())}
        >
          {workflow.status === 'draft' ? (saveDraft.isPending ? 'Saving…' : 'Save') : drafting ? 'Proposing…' : 'Propose these steps'}
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={() => setIsEditing(false)}>
          Cancel
        </Button>
      </div>

      {hasInvalidAssignee && <p className="text-[12px] text-destructive">Every task or notify step needs a valid assignee before you can save.</p>}
      {saveDraft.isError && <p className="text-[12px] text-destructive">{(saveDraft.error as Error).message}</p>}
      {proposeActive.isError && <p className="text-[12px] text-destructive">{(proposeActive.error as Error).message}</p>}

      {edit?.status === 'pending' && <EditWatcher key={edit.id} companyId={companyId} workflowId={workflow.id} editId={edit.id} onEvent={onEditEvent} />}
      {edit?.status === 'unchanged' && <p className="text-[13px] text-muted-foreground">That wouldn't change this workflow.</p>}
      {edit?.status === 'failed' && <p className="text-[13px] text-destructive">{edit.error_message}</p>}
      {edit?.status === 'proposed' && edit.change_proposal_id !== null && (
        <ProposedChange key={edit.change_proposal_id} companyId={companyId} proposalId={edit.change_proposal_id} people={people} />
      )}

      {openStep && (
        <StepEditPanel
          step={openStep}
          integrations={integrationsQuery.data?.data ?? []}
          onChange={updateStep}
          onDelete={() => deleteStep(openStep.key)}
          onClose={() => setOpenStepKey(null)}
        />
      )}
    </div>
  )
}
