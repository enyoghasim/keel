import { useMutation, useQueryClient } from '@tanstack/react-query'
import type { ChangeProposal, Envelope } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

function statusNote(proposal: ChangeProposal) {
  const decidedAt = proposal.decided_at ? ` on ${new Date(proposal.decided_at).toLocaleString()}` : ''
  return `This proposal was ${proposal.status}${decidedAt}.`
}

export function ApproveRejectBar({
  companyId,
  proposal,
  brokenCount,
  canDecide,
}: {
  companyId: string
  proposal: ChangeProposal
  brokenCount: number
  canDecide: boolean
}) {
  const queryClient = useQueryClient()
  const [approveAnyway, setApproveAnyway] = useState(false)
  const [reason, setReason] = useState('')
  const [rejectReason, setRejectReason] = useState('')

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['change_proposals', companyId] })

  const approve = useMutation({
    mutationFn: () =>
      api.post<Envelope<ChangeProposal>>(
        `/companies/${companyId}/change_proposals/${proposal.id}/approve`,
        approveAnyway ? { approve_anyway: true, reason } : {},
      ),
    onSuccess: invalidate,
  })

  const reject = useMutation({
    mutationFn: () =>
      api.post<Envelope<ChangeProposal>>(
        `/companies/${companyId}/change_proposals/${proposal.id}/reject`,
        rejectReason.trim() ? { reason: rejectReason.trim() } : {},
      ),
    onSuccess: invalidate,
  })

  if (proposal.status !== 'pending') {
    return <p className="text-[13px] text-muted-foreground">{statusNote(proposal)}</p>
  }

  if (!canDecide) {
    return <p className="text-[13px] text-muted-foreground">Waiting for an HR admin to approve or reject this proposal.</p>
  }

  // SPEC.md section 10: Approve is disabled while there are broken chains,
  // unless "Approve anyway" is ticked with a reason — mirrors the
  // controller's refusal in Api::ChangeProposalsController#approve.
  const approveDisabled = brokenCount > 0 && (!approveAnyway || reason.trim() === '')

  return (
    <div className="space-y-2.5">
      {brokenCount > 0 && (
        <label className="flex items-start gap-2 text-[13px]">
          <input
            type="checkbox"
            checked={approveAnyway}
            onChange={(e) => setApproveAnyway(e.target.checked)}
            className="mt-0.5"
          />
          <span className="flex-1">
            Approve anyway, despite {brokenCount} broken {brokenCount === 1 ? 'chain' : 'chains'}
            {approveAnyway && (
              <input
                type="text"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="Reason for approving anyway"
                aria-label="Reason for approving anyway"
                className="mt-1.5 block w-full rounded border border-border bg-card px-2.5 py-1.5 text-[13px]"
              />
            )}
          </span>
        </label>
      )}

      <Input
        type="text"
        value={rejectReason}
        onChange={(e) => setRejectReason(e.target.value)}
        placeholder="Reason for rejecting (optional)"
        aria-label="Reason for rejecting (optional)"
      />

      <div className="flex items-center gap-2">
        <Button type="button" onClick={() => approve.mutate()} disabled={approveDisabled || approve.isPending}>
          Approve
        </Button>
        <Button type="button" variant="outline" onClick={() => reject.mutate()} disabled={reject.isPending}>
          Reject
        </Button>
      </div>

      {approve.isError && <p className="text-[13px] text-destructive">{(approve.error as Error).message}</p>}
      {reject.isError && <p className="text-[13px] text-destructive">{(reject.error as Error).message}</p>}
    </div>
  )
}
