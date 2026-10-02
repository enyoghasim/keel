import { useQuery } from '@tanstack/react-query'
import type { Envelope, PolicyTestResult, PolicyWithRules } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { PagePlaceholder } from '../layout/page-placeholder'
import { HandbookPane } from './handbook-pane'
import { PolicyTester } from './policy-tester'
import { RuleCard } from './rule-card'

export function PolicyDetail({ companyId, policyId }: { companyId: string; policyId: number }) {
  const [hoveredRuleId, setHoveredRuleId] = useState<number | null>(null)
  const [testResult, setTestResult] = useState<PolicyTestResult | null>(null)

  const policyQuery = useQuery({
    queryKey: ['policy', companyId, policyId],
    queryFn: () => api.get<Envelope<PolicyWithRules>>(`/companies/${companyId}/policies/${policyId}`),
  })

  if (policyQuery.isPending) return <PagePlaceholder note="Loading policy…" />
  if (policyQuery.isError) {
    return <PagePlaceholder note={`Couldn't load this policy: ${(policyQuery.error as Error).message}`} />
  }

  const policy = policyQuery.data?.data
  if (!policy) return null

  const matchedRuleKeys = new Set(testResult?.matched_rule_keys ?? [])

  return (
    <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
      <div>
        <h3 className="mb-2 text-[12px] font-semibold uppercase tracking-wider text-muted-foreground">Handbook</h3>
        <HandbookPane rules={policy.rules} highlightedRuleId={hoveredRuleId} />
      </div>

      <div className="space-y-4">
        <PolicyTester companyId={companyId} policyId={policyId} onResult={setTestResult} />

        <div>
          <h3 className="mb-2 text-[12px] font-semibold uppercase tracking-wider text-muted-foreground">Rules</h3>
          {policy.rules.length === 0 ? (
            <PagePlaceholder note="No rules extracted for this policy yet." />
          ) : (
            <div className="space-y-2.5">
              {policy.rules.map((rule) => (
                <RuleCard
                  key={rule.id}
                  rule={rule}
                  matched={matchedRuleKeys.has(rule.key)}
                  onHover={setHoveredRuleId}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
