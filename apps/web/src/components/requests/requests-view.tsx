import { useQuery } from '@tanstack/react-query'
import type { Envelope, Person, Request } from 'api-types'
import { api } from '../../lib/api'
import { useCurrentPerson } from '../../lib/auth'
import { PagePlaceholder } from '../layout/page-placeholder'
import { RequestRow } from './request-row'

/**
 * The requests the signed-in person submitted themselves — leave, expense,
 * equipment — newest first, each with its decision and, while a workflow is
 * still running, which step it's on and who it's waiting for. The
 * complement of Inbox: that page is what's waiting on you to act; this one
 * is what you're waiting on.
 */
export function RequestsView({ companyId }: { companyId: string }) {
  const currentPersonQuery = useCurrentPerson(companyId)
  const currentPerson = currentPersonQuery.data?.data

  const requestsQuery = useQuery({
    queryKey: ['requests', companyId, { requester_id: currentPerson?.id }],
    queryFn: () => api.get<Envelope<Request[]>>(`/companies/${companyId}/requests?requester_id=${currentPerson!.id}`),
    enabled: currentPerson !== undefined,
  })
  const peopleQuery = useQuery({
    queryKey: ['people', companyId],
    queryFn: () => api.get<Envelope<Person[]>>(`/companies/${companyId}/people`),
  })

  if (currentPersonQuery.isPending || requestsQuery.isPending || peopleQuery.isPending) {
    return <PagePlaceholder note="Loading your requests…" />
  }

  const failedQuery = [currentPersonQuery, requestsQuery, peopleQuery].find((q) => q.isError)
  if (failedQuery) {
    return <PagePlaceholder note={`Couldn't load your requests: ${(failedQuery.error as Error).message}`} />
  }

  if (!currentPerson) return <PagePlaceholder note="Couldn't load your requests: no signed-in person." />

  const people = new Map((peopleQuery.data?.data ?? []).map((person) => [person.id, person]))
  const requests = [...(requestsQuery.data?.data ?? [])].sort((a, b) => b.created_at.localeCompare(a.created_at))

  if (requests.length === 0) {
    return <PagePlaceholder note="You haven't submitted any requests yet — ask Keel to file one, or use a policy's test form." />
  }

  return (
    <div className="space-y-3">
      {requests.map((request) => (
        <RequestRow key={request.id} request={request} people={people} />
      ))}
    </div>
  )
}
