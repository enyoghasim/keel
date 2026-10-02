import { useQuery } from '@tanstack/react-query'
import type { Envelope, Policy } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { PagePlaceholder } from '../layout/page-placeholder'
import { PolicyDetail } from './policy-detail'
import { PolicyList } from './policy-list'

export function PoliciesView({ companyId }: { companyId: string }) {
  const [selectedPolicyId, setSelectedPolicyId] = useState<number | null>(null)

  const policiesQuery = useQuery({
    queryKey: ['policies', companyId],
    queryFn: () => api.get<Envelope<Policy[]>>(`/companies/${companyId}/policies`),
  })

  if (policiesQuery.isPending) return <PagePlaceholder note="Loading policies…" />
  if (policiesQuery.isError) {
    return <PagePlaceholder note={`Couldn't load policies: ${(policiesQuery.error as Error).message}`} />
  }

  const policies = policiesQuery.data?.data ?? []
  if (policies.length === 0) {
    return (
      <PagePlaceholder note="No policies yet. They're extracted from the handbook during Assemble." />
    )
  }

  const activePolicyId = selectedPolicyId ?? policies[0].id

  return (
    <div className="space-y-4">
      <PolicyList policies={policies} activePolicyId={activePolicyId} onSelect={setSelectedPolicyId} />
      <PolicyDetail companyId={companyId} policyId={activePolicyId} />
    </div>
  )
}
