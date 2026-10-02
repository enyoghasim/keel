import { useState } from 'react'

// SPEC.md section 8: "Approve and Reject buttons and an override reason
// field" — an approver can flip the engine's decision, but only with a
// required reason, which feeds the eval loop later (section 12).
export function OverrideDialog({
  onSubmit,
  pending,
}: {
  onSubmit: (reason: string) => void
  pending: boolean
}) {
  const [open, setOpen] = useState(false)
  const [reason, setReason] = useState('')

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="text-[12.5px] font-medium text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
      >
        Override
      </button>
    )
  }

  return (
    <div className="flex flex-1 items-start gap-2">
      <input
        type="text"
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="Reason for overriding the engine's decision"
        aria-label="Reason for overriding the engine's decision"
        className="flex-1 rounded border border-border bg-card px-2.5 py-1.5 text-[13px]"
      />
      <button
        type="button"
        onClick={() => onSubmit(reason)}
        disabled={reason.trim() === '' || pending}
        className="shrink-0 rounded border border-border bg-card px-3 py-1.5 text-[12.5px] font-medium disabled:cursor-not-allowed disabled:opacity-40"
      >
        Confirm override
      </button>
      <button
        type="button"
        onClick={() => setOpen(false)}
        className="shrink-0 text-[12.5px] text-muted-foreground hover:text-foreground"
      >
        Cancel
      </button>
    </div>
  )
}
