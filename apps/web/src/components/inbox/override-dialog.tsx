import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

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
      <Button type="button" variant="ghost" size="sm" onClick={() => setOpen(true)} className="text-muted-foreground">
        Override
      </Button>
    )
  }

  return (
    <div className="flex flex-1 flex-wrap items-start gap-2">
      <Input
        type="text"
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="Reason for overriding the engine's decision"
        aria-label="Reason for overriding the engine's decision"
        className="min-w-48 flex-1"
      />
      <Button type="button" variant="outline" onClick={() => onSubmit(reason)} disabled={reason.trim() === '' || pending}>
        Confirm override
      </Button>
      <Button type="button" variant="ghost" onClick={() => setOpen(false)} className="text-muted-foreground">
        Cancel
      </Button>
    </div>
  )
}
