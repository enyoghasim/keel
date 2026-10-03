import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, PolicyTestResult, PolicyWithRules, RuleResolution } from 'api-types'
import { useCallback, useEffect, useState } from 'react'
import { api } from '../../lib/api'
import { CABLE_POLL_INTERVAL_MS, useCableHealthy, useChannel } from '../../lib/cable'
import { PagePlaceholder } from '../layout/page-placeholder'
import { ConflictList } from './conflict-list'
import { HandbookPane } from './handbook-pane'
import { PolicyTester } from './policy-tester'
import { PublishBar } from './publish-bar'
import { RuleCard } from './rule-card'
import { RuleUpdate } from './rule-update'

// Follows one answer while the model rewrites the rule. The channel sends the
// current state on subscribe, so a job that already finished isn't missed.
// While the socket looks unreachable, polls the same resource instead.
function ResolutionWatcher({
  companyId,
  policyId,
  resolutionId,
  onEvent,
}: {
  companyId: string
  policyId: number
  resolutionId: number
  onEvent: (resolution: RuleResolution) => void
}) {
  const cableHealthy = useCableHealthy()
  useChannel<RuleResolution>('RuleResolutionChannel', { rule_resolution_id: resolutionId }, onEvent)

  const poll = useQuery({
    queryKey: ['rule_resolution', companyId, policyId, resolutionId],
    queryFn: () => api.get<Envelope<RuleResolution>>(`/companies/${companyId}/policies/${policyId}/rule_resolutions/${resolutionId}`),
    enabled: !cableHealthy,
    refetchInterval: cableHealthy ? false : CABLE_POLL_INTERVAL_MS,
  })
  useEffect(() => {
    if (poll.data?.data) onEvent(poll.data.data)
  }, [poll.data, onEvent])

  return null
}

export function PolicyDetail({ companyId, policyId }: { companyId: string; policyId: number }) {
  const [hoveredRuleId, setHoveredRuleId] = useState<number | null>(null)
  const [testResult, setTestResult] = useState<PolicyTestResult | null>(null)
  const [resolution, setResolution] = useState<RuleResolution | null>(null)
  const queryClient = useQueryClient()

  const answer = useMutation({
    mutationFn: (vars: { ruleId: number; ambiguityIndex: number; option: string }) =>
      api.post<Envelope<RuleResolution>>(`/companies/${companyId}/policies/${policyId}/rule_resolutions`, {
        rule_id: vars.ruleId,
        ambiguity_index: vars.ambiguityIndex,
        answer: vars.option,
      }),
    onSuccess: (response) => setResolution(response.data ?? null),
  })

  const onResolution = useCallback(
    (event: RuleResolution) => {
      setResolution(event)
      if (event.status === 'resolved') {
        // The new rule version replaces the old one, and the conflicts may have changed.
        void queryClient.invalidateQueries({
          queryKey: ['policy', companyId, policyId],
        })
        void queryClient.invalidateQueries({
          queryKey: ['policy-conflicts', companyId, policyId],
        })
      }
    },
    [queryClient, companyId, policyId],
  )

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

  const applying = answer.isPending || resolution?.status === 'pending'
  const answerError = answer.isError
    ? (answer.error as Error).message
    : resolution?.status === 'failed'
      ? resolution.error_message
      : null

  return (
    <div className="space-y-4">
      <PublishBar companyId={companyId} policy={policy} />
      {resolution?.status === 'pending' && (
        <ResolutionWatcher key={resolution.id} companyId={companyId} policyId={policyId} resolutionId={resolution.id} onEvent={onResolution} />
      )}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div>
          <h3 className="mb-2 text-[12px] font-semibold uppercase tracking-wider text-muted-foreground">Handbook</h3>
          <HandbookPane rules={policy.rules} highlightedRuleId={hoveredRuleId} />
        </div>

        <div className="space-y-4">
          {resolution && <RuleUpdate resolution={resolution} />}
          <PolicyTester companyId={companyId} policyId={policyId} onResult={setTestResult} />
          <ConflictList companyId={companyId} policyId={policyId} canFix={policy.status !== 'active'} />

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
                    answering={applying && answer.variables?.ruleId === rule.id ? answer.variables.option : null}
                    answerError={answer.variables?.ruleId === rule.id ? answerError : null}
                    onAnswer={(ambiguityIndex, option) => answer.mutate({ ruleId: rule.id, ambiguityIndex, option })}
                  />
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
