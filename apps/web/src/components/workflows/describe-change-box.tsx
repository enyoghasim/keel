import { useMutation, useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import type { ChangeProposal, Envelope, Person, WorkflowChangeProposal, WorkflowEdit } from 'api-types'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { api } from '../../lib/api'
import { CABLE_POLL_INTERVAL_MS, useCableHealthy, useChannel } from '../../lib/cable'
import { WorkflowProposalDetails } from '../proposals/workflow-proposal-details'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

export function ProposedChange({ companyId, proposalId, people }: { companyId: string; proposalId: number; people: Person[] }) {
  const proposalQuery = useQuery({
    queryKey: ['change_proposal', companyId, proposalId],
    queryFn: () => api.get<Envelope<ChangeProposal>>(`/companies/${companyId}/change_proposals/${proposalId}`),
  })
  const peopleById = useMemo(() => new Map(people.map((person) => [person.id, person])), [people])

  const proposal = proposalQuery.data?.data
  if (proposalQuery.isError) return <p className="text-[13px] text-destructive">Couldn't load the proposal.</p>
  if (!proposal || proposal.kind !== 'workflow') return <p className="text-[13px] text-muted-foreground">Loading the proposal…</p>

  return (
    <div className="space-y-3">
      <p className="text-[13px] font-medium">{(proposal as WorkflowChangeProposal).title}</p>
      <WorkflowProposalDetails proposal={proposal} people={peopleById} />
      <p className="text-[13px] text-muted-foreground">
        Nothing has changed yet.{' '}
        <Link to="/proposals" className="font-medium text-brand hover:underline">
          Review and approve it on Proposals
        </Link>
        .
      </p>
    </div>
  )
}

// Follows one drafting edit over Action Cable until it settles. While the
// socket looks unreachable, polls the same resource instead — same shape
// as the channel's own payload, so it feeds the same onEvent either way.
export function EditWatcher({
  companyId,
  workflowId,
  editId,
  onEvent,
}: {
  companyId: string
  workflowId: number
  editId: number
  onEvent: (event: WorkflowEdit) => void
}) {
  const cableHealthy = useCableHealthy()
  useChannel<WorkflowEdit>('WorkflowEditChannel', { workflow_edit_id: editId }, onEvent)

  const poll = useQuery({
    queryKey: ['workflow_edit', companyId, workflowId, editId],
    queryFn: () => api.get<Envelope<WorkflowEdit>>(`/companies/${companyId}/workflows/${workflowId}/edits/${editId}`),
    enabled: !cableHealthy,
    refetchInterval: cableHealthy ? false : CABLE_POLL_INTERVAL_MS,
  })
  useEffect(() => {
    if (poll.data?.data) onEvent(poll.data.data)
  }, [poll.data, onEvent])

  return null
}

// "Describe a change" (SPEC.md section 8): the instruction goes to the API,
// which has the model draft a whole new workflow and files it as a pending
// change proposal with its impact — the page follows that over Action
// Cable and shows the proposed graph, added steps outlined green and
// removed ones red. Nothing is applied until an HR admin approves it.
export function DescribeChangeBox({ companyId, workflowId, people }: { companyId: string; workflowId: number; people: Person[] }) {
  const [instruction, setInstruction] = useState('')
  const [edit, setEdit] = useState<WorkflowEdit | null>(null)

  const submit = useMutation({
    mutationFn: (text: string) => api.post<Envelope<WorkflowEdit>>(`/companies/${companyId}/workflows/${workflowId}/edits`, { instruction: text }),
    onSuccess: (response) => setEdit(response.data ?? null),
  })

  const onEvent = useCallback((event: WorkflowEdit) => setEdit(event), [])

  const drafting = submit.isPending || edit?.status === 'pending'

  return (
    <div className="space-y-3">
      <form
        onSubmit={(e) => {
          e.preventDefault()
          if (instruction.trim() !== '' && !drafting) submit.mutate(instruction.trim())
        }}
        className="flex flex-col gap-2 sm:flex-row"
      >
        <label htmlFor="describe-change" className="sr-only">
          Describe a change
        </label>
        <Input
          id="describe-change"
          type="text"
          value={instruction}
          onChange={(e) => setInstruction(e.target.value)}
          placeholder="Describe a change, e.g. add a step where IT sets up accounts after the manager approves"
          className="h-9 text-[14px]"
        />
        <Button type="submit" disabled={instruction.trim() === '' || drafting} className="h-9 shrink-0 px-4">
          {drafting ? 'Drafting…' : 'Propose change'}
        </Button>
      </form>

      {edit?.status === 'pending' && <EditWatcher key={edit.id} companyId={companyId} workflowId={workflowId} editId={edit.id} onEvent={onEvent} />}
      {submit.isError && <p className="text-[13px] text-destructive">{(submit.error as Error).message}</p>}
      {edit?.status === 'failed' && <p className="text-[13px] text-destructive">{edit.error_message}</p>}
      {edit?.status === 'unchanged' && <p className="text-[13px] text-muted-foreground">That wouldn't change this workflow.</p>}
      {edit?.status === 'proposed' && edit.change_proposal_id !== null && (
        <ProposedChange key={edit.change_proposal_id} companyId={companyId} proposalId={edit.change_proposal_id} people={people} />
      )}
    </div>
  )
}

