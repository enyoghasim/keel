import { useMutation } from '@tanstack/react-query'
import type { Envelope, Person, WorkflowTestRunResult } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'

/**
 * "Test run" (SPEC.md section 8): picks a requester and a payload, then
 * calls Workflows::Runtime#dry_run via POST .../test_run. Nothing is saved
 * — the result is handed back to the caller, which lights up FlowCanvas.
 */
export function TestRunDialog({
  companyId,
  workflowId,
  people,
  onClose,
  onResult,
}: {
  companyId: string
  workflowId: number
  people: Person[]
  onClose: () => void
  onResult: (result: WorkflowTestRunResult) => void
}) {
  const [requesterId, setRequesterId] = useState('')
  const [amountEur, setAmountEur] = useState('')
  const [category, setCategory] = useState('')
  const [days, setDays] = useState('')
  const [noticeDays, setNoticeDays] = useState('')

  const testRun = useMutation({
    mutationFn: () => {
      const payload: Record<string, unknown> = {}
      if (amountEur.trim() !== '') payload.amount_eur = Number(amountEur)
      if (category.trim() !== '') payload.category = category.trim()
      if (days.trim() !== '') payload.days = Number(days)
      if (noticeDays.trim() !== '') payload.notice_days = Number(noticeDays)

      return api.post<Envelope<WorkflowTestRunResult>>(`/companies/${companyId}/workflows/${workflowId}/test_run`, {
        requester_id: requesterId,
        payload,
      })
    },
    onSuccess: (response) => {
      if (response.data) {
        onResult(response.data)
        onClose()
      }
    },
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" role="presentation">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="test-run-dialog-title"
        className="w-full max-w-md rounded-lg border border-border bg-card p-4 shadow-lg"
      >
        <div className="flex items-center justify-between">
          <h2 id="test-run-dialog-title" className="text-[14px] font-semibold">
            Test run
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="rounded px-1.5 py-0.5 text-[13px] text-muted-foreground hover:bg-secondary"
          >
            ✕
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            if (requesterId !== '') testRun.mutate()
          }}
          className="mt-3 grid grid-cols-2 gap-2.5"
        >
          <div className="col-span-2">
            <label htmlFor="test-run-requester" className="block text-[12px] font-medium">
              Requester
            </label>
            <select
              id="test-run-requester"
              value={requesterId}
              onChange={(e) => setRequesterId(e.target.value)}
              className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
            >
              <option value="">Choose a person…</option>
              {people.map((person) => (
                <option key={person.id} value={person.id}>
                  {person.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="test-run-amount" className="block text-[12px] font-medium">
              Amount (EUR)
            </label>
            <input
              id="test-run-amount"
              type="number"
              value={amountEur}
              onChange={(e) => setAmountEur(e.target.value)}
              className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
            />
          </div>

          <div>
            <label htmlFor="test-run-category" className="block text-[12px] font-medium">
              Category
            </label>
            <input
              id="test-run-category"
              type="text"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              placeholder="conference"
              className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
            />
          </div>

          <div>
            <label htmlFor="test-run-days" className="block text-[12px] font-medium">
              Days
            </label>
            <input
              id="test-run-days"
              type="number"
              value={days}
              onChange={(e) => setDays(e.target.value)}
              className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
            />
          </div>

          <div>
            <label htmlFor="test-run-notice-days" className="block text-[12px] font-medium">
              Notice days
            </label>
            <input
              id="test-run-notice-days"
              type="number"
              value={noticeDays}
              onChange={(e) => setNoticeDays(e.target.value)}
              className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
            />
          </div>

          {testRun.isError && (
            <p className="col-span-2 text-[13px] text-destructive">{(testRun.error as Error).message}</p>
          )}

          <div className="col-span-2 mt-1 flex justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="rounded border border-border px-3.5 py-1.5 text-[13px] font-medium hover:bg-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={requesterId === '' || testRun.isPending}
              className="rounded bg-primary px-3.5 py-1.5 text-[13px] font-medium text-primary-foreground shadow-btn disabled:cursor-not-allowed disabled:opacity-40"
            >
              {testRun.isPending ? 'Running…' : 'Run test'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
