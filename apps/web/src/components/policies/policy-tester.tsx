import { useMutation, useQuery } from '@tanstack/react-query'
import type { Envelope, Person, PolicyTestResult } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

const OUTCOME_LABEL: Record<PolicyTestResult['outcome'], string> = {
  auto_approve: 'Auto approve',
  require_approval: 'Needs approval',
  reject: 'Reject',
  blocked: 'Blocked',
}

const OUTCOME_TONE: Record<PolicyTestResult['outcome'], string> = {
  auto_approve: 'border-success/40 bg-success-muted text-success',
  require_approval: 'border-info/40 bg-info-muted text-info',
  reject: 'border-destructive/40 bg-destructive-muted text-destructive',
  blocked: 'border-destructive/40 bg-destructive-muted text-destructive',
}

function personLabel(people: Person[], id: number): string {
  return people.find((p) => p.id === id)?.name ?? `Person #${id}`
}

export function PolicyTester({
  companyId,
  policyId,
  onResult,
}: {
  companyId: string
  policyId: number
  onResult: (result: PolicyTestResult | null) => void
}) {
  const [requesterId, setRequesterId] = useState('')
  const [amountEur, setAmountEur] = useState('')
  const [category, setCategory] = useState('')
  const [days, setDays] = useState('')
  const [noticeDays, setNoticeDays] = useState('')

  const peopleQuery = useQuery({
    queryKey: ['people', companyId],
    queryFn: () => api.get<Envelope<Person[]>>(`/companies/${companyId}/people`),
  })
  const people = peopleQuery.data?.data ?? []

  const test = useMutation({
    mutationFn: () => {
      const payload: Record<string, unknown> = {}
      if (amountEur.trim() !== '') payload.amount_eur = Number(amountEur)
      if (category.trim() !== '') payload.category = category.trim()
      if (days.trim() !== '') payload.days = Number(days)
      if (noticeDays.trim() !== '') payload.notice_days = Number(noticeDays)

      return api.post<Envelope<PolicyTestResult>>(`/companies/${companyId}/policies/${policyId}/test`, {
        requester_id: requesterId,
        payload,
      })
    },
    onSuccess: (response) => onResult(response.data ?? null),
  })

  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <h3 className="text-[12px] font-semibold uppercase tracking-wider text-muted-foreground">Test this policy</h3>

      <form
        onSubmit={(e) => {
          e.preventDefault()
          if (requesterId !== '') test.mutate()
        }}
        className="mt-2.5 grid grid-cols-2 gap-2.5"
      >
        <div className="col-span-2">
          <label htmlFor="tester-requester" className="block text-[12px] font-medium">
            Requester
          </label>
          <Select value={requesterId} onValueChange={setRequesterId}>
            <SelectTrigger id="tester-requester" className="mt-1">
              <SelectValue placeholder="Choose a person…" />
            </SelectTrigger>
            <SelectContent>
              {people.map((person) => (
                <SelectItem key={person.id} value={String(person.id)}>
                  {person.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div>
          <label htmlFor="tester-amount" className="block text-[12px] font-medium">
            Amount (EUR)
          </label>
          <input
            id="tester-amount"
            type="number"
            value={amountEur}
            onChange={(e) => setAmountEur(e.target.value)}
            className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
          />
        </div>

        <div>
          <label htmlFor="tester-category" className="block text-[12px] font-medium">
            Category
          </label>
          <input
            id="tester-category"
            type="text"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="conference"
            className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
          />
        </div>

        <div>
          <label htmlFor="tester-days" className="block text-[12px] font-medium">
            Days
          </label>
          <input
            id="tester-days"
            type="number"
            value={days}
            onChange={(e) => setDays(e.target.value)}
            className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
          />
        </div>

        <div>
          <label htmlFor="tester-notice-days" className="block text-[12px] font-medium">
            Notice days
          </label>
          <input
            id="tester-notice-days"
            type="number"
            value={noticeDays}
            onChange={(e) => setNoticeDays(e.target.value)}
            className="mt-1 block w-full rounded border border-border bg-background px-2.5 py-1.5 text-[13px]"
          />
        </div>

        <button
          type="submit"
          disabled={requesterId === '' || test.isPending}
          className="col-span-2 mt-1 rounded bg-primary px-3.5 py-1.5 text-[13px] font-medium text-primary-foreground shadow-btn disabled:cursor-not-allowed disabled:opacity-40"
        >
          {test.isPending ? 'Running…' : 'Run test'}
        </button>
      </form>

      {test.isError && <p className="mt-2 text-[13px] text-destructive">{(test.error as Error).message}</p>}

      {test.data?.data && (
        <div className="mt-3 space-y-1.5 rounded border border-border bg-secondary p-3">
          <span
            className={`inline-block rounded border px-1.5 py-0.5 text-[11px] font-medium ${OUTCOME_TONE[test.data.data.outcome]}`}
          >
            {OUTCOME_LABEL[test.data.data.outcome]}
          </span>
          {test.data.data.explanation && <p className="text-[13px]">{test.data.data.explanation}</p>}
          {test.data.data.approvers.length > 0 && (
            <p className="text-[12px] text-muted-foreground">
              Approvers: {test.data.data.approvers.map((id) => personLabel(people, id)).join(', ')}
            </p>
          )}
          {test.data.data.errors.map((error) => (
            <p key={error} className="text-[12px] text-destructive">
              {error}
            </p>
          ))}
        </div>
      )}
    </div>
  )
}
