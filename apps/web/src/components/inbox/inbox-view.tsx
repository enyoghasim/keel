import { useQuery } from '@tanstack/react-query'
import type { Envelope, Person, Request, StepRun } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { PagePlaceholder } from '../layout/page-placeholder'
import { StepRunRow } from './step-run-row'

interface ActionableRow {
  request: Request
  stepRun: StepRun
}

// A step_run is actually waiting on someone once Workflows::Runtime has
// resolved and assigned it — "pending" alone just means it exists in the
// sequence but hasn't become the active step yet (see runtime.rb#advance!).
function actionableRows(requests: Request[]): ActionableRow[] {
  return requests.flatMap((request) =>
    (request.workflow_run?.step_runs ?? [])
      .filter((stepRun) => stepRun.status === 'pending' && stepRun.resolved_person_id !== null)
      .map((stepRun) => ({ request, stepRun })),
  )
}

export function InboxView({ companyId }: { companyId: string }) {
  const [actingAs, setActingAs] = useState<string>('all')

  const requestsQuery = useQuery({
    queryKey: ['requests', companyId],
    queryFn: () => api.get<Envelope<Request[]>>(`/companies/${companyId}/requests`),
  })
  const peopleQuery = useQuery({
    queryKey: ['people', companyId],
    queryFn: () => api.get<Envelope<Person[]>>(`/companies/${companyId}/people`),
  })

  if (requestsQuery.isPending || peopleQuery.isPending) {
    return <PagePlaceholder note="Loading inbox…" />
  }

  const failedQuery = [requestsQuery, peopleQuery].find((q) => q.isError)
  if (failedQuery) {
    return <PagePlaceholder note={`Couldn't load the inbox: ${(failedQuery.error as Error).message}`} />
  }

  const people = new Map((peopleQuery.data?.data ?? []).map((person) => [person.id, person]))
  const rows = actionableRows(requestsQuery.data?.data ?? [])

  if (rows.length === 0) {
    return <PagePlaceholder note="All caught up — nothing is waiting on an approval or task right now." />
  }

  const assignees = [...new Set(rows.map((row) => row.stepRun.resolved_person_id).filter((id): id is number => id !== null))]
  const visibleRows = actingAs === 'all' ? rows : rows.filter((row) => String(row.stepRun.resolved_person_id) === actingAs)

  return (
    <div className="space-y-3">
      <label className="flex items-center gap-2 text-[13px] text-muted-foreground">
        Acting as
        <select
          value={actingAs}
          onChange={(e) => setActingAs(e.target.value)}
          className="rounded border border-border bg-card px-2 py-1 text-[13px] text-foreground"
        >
          <option value="all">Everyone</option>
          {assignees.map((id) => (
            <option key={id} value={id}>
              {people.get(id)?.name ?? `person #${id}`}
            </option>
          ))}
        </select>
      </label>

      {visibleRows.length === 0 ? (
        <PagePlaceholder note="Nothing waiting on this person right now." />
      ) : (
        <div className="space-y-3">
          {visibleRows.map((row) => (
            <StepRunRow key={row.stepRun.id} companyId={companyId} request={row.request} stepRun={row.stepRun} people={people} />
          ))}
        </div>
      )}
    </div>
  )
}
