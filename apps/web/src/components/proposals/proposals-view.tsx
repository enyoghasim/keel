import { useQuery } from '@tanstack/react-query'
import type { ChangeProposal, Department, Envelope, Person } from 'api-types'
import { api } from '../../lib/api'
import { PagePlaceholder } from '../layout/page-placeholder'
import { ProposalRow } from './proposal-row'

export function ProposalsView({ companyId }: { companyId: string }) {
  const proposalsQuery = useQuery({
    queryKey: ['change_proposals', companyId],
    queryFn: () => api.get<Envelope<ChangeProposal[]>>(`/companies/${companyId}/change_proposals`),
  })
  const peopleQuery = useQuery({
    queryKey: ['people', companyId],
    queryFn: () => api.get<Envelope<Person[]>>(`/companies/${companyId}/people`),
  })
  const departmentsQuery = useQuery({
    queryKey: ['departments', companyId],
    queryFn: () => api.get<Envelope<Department[]>>(`/companies/${companyId}/departments`),
  })

  if (proposalsQuery.isPending || peopleQuery.isPending || departmentsQuery.isPending) {
    return <PagePlaceholder note="Loading proposals…" />
  }

  const failedQuery = [proposalsQuery, peopleQuery, departmentsQuery].find((q) => q.isError)
  if (failedQuery) {
    return <PagePlaceholder note={`Couldn't load proposals: ${(failedQuery.error as Error).message}`} />
  }

  const proposals = proposalsQuery.data?.data ?? []
  if (proposals.length === 0) {
    return (
      <PagePlaceholder note="No change proposals yet. They show up here whenever the agent or a person proposes an org, rule or workflow change." />
    )
  }

  const people = new Map((peopleQuery.data?.data ?? []).map((person) => [person.id, person]))
  const departments = new Map((departmentsQuery.data?.data ?? []).map((department) => [department.id, department]))

  return (
    <div className="space-y-3">
      {proposals.map((proposal) => (
        <ProposalRow key={proposal.id} proposal={proposal} companyId={companyId} people={people} departments={departments} />
      ))}
    </div>
  )
}
