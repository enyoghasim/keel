import type { Policy, PolicyStatus } from 'api-types'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'

const STATUS_LABEL: Record<PolicyStatus, string> = {
  draft: 'Draft',
  active: 'Active',
  needs_review: 'Needs review',
  superseded: 'Superseded',
}

const STATUS_VARIANT: Record<PolicyStatus, 'secondary' | 'success' | 'warning'> = {
  draft: 'secondary',
  active: 'success',
  needs_review: 'warning',
  superseded: 'secondary',
}

export function PolicyList({
  policies,
  activePolicyId,
  onSelect,
}: {
  policies: Policy[]
  activePolicyId: number
  onSelect: (policyId: number) => void
}) {
  return (
    <Tabs value={String(activePolicyId)} onValueChange={(value) => onSelect(Number(value))}>
      <TabsList aria-label="Policies">
        {policies.map((policy) => (
          <TabsTrigger key={policy.id} value={String(policy.id)}>
            {policy.title}
            <Badge variant={STATUS_VARIANT[policy.status]}>
              {STATUS_LABEL[policy.status]}
            </Badge>
          </TabsTrigger>
        ))}
      </TabsList>
    </Tabs>
  )
}
