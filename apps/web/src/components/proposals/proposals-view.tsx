import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { ChangeProposal, Department, Envelope, Person } from 'api-types'
import { useCallback } from 'react'
import { api } from '../../lib/api'
import { useCurrentPerson } from '../../lib/auth'
import { CABLE_POLL_INTERVAL_MS, useCableHealthy, useChannel } from '../../lib/cable'
import { PagePlaceholder } from '../layout/page-placeholder'
import { ProposalRow } from './proposal-row'

export function ProposalsView({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const canDecide = useCurrentPerson(companyId).data?.data?.roles.includes('hr_admin') ?? false
  const cableHealthy = useCableHealthy()
  const proposalsQuery = useQuery({
    queryKey: ['change_proposals', companyId],
    queryFn: () => api.get<Envelope<ChangeProposal[]>>(`/companies/${companyId}/change_proposals`),
    refetchInterval: cableHealthy ? false : CABLE_POLL_INTERVAL_MS,
  })
  const peopleQuery = useQuery({
    queryKey: ['people', companyId],
    queryFn: () => api.get<Envelope<Person[]>>(`/companies/${companyId}/people`),
  })
  const departmentsQuery = useQuery({
    queryKey: ['departments', companyId],
    queryFn: () => api.get<Envelope<Department[]>>(`/companies/${companyId}/departments`),
  })

  // A proposal's plain-English explanation is written by a job after it is
  // created, so refresh the list when one arrives.
  const onExplained = useCallback(() => queryClient.invalidateQueries({ queryKey: ['change_proposals', companyId] }), [queryClient, companyId])
  useChannel('ChangeProposalChannel', { company_id: companyId }, onExplained)

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
        <ProposalRow
          key={proposal.id}
          proposal={proposal}
          companyId={companyId}
          people={people}
          departments={departments}
          canDecide={canDecide}
        />
      ))}
    </div>
  )
}
