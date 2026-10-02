import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, RuleConflict } from 'api-types'
import { api } from '../../lib/api'
import { Button } from '@/components/ui/button'

// Rules::ConflictReport (SPEC.md section 7): found without a model, explained
// in a sentence, with the usual fix one click away for a draft policy.
export function ConflictList({
  companyId,
  policyId,
  canFix,
}: {
  companyId: string
  policyId: number
  canFix: boolean
}) {
  const queryClient = useQueryClient()
  const conflictsKey = ['policy-conflicts', companyId, policyId]

  const conflicts = useQuery({
    queryKey: conflictsKey,
    queryFn: () => api.get<Envelope<RuleConflict[]>>(`/companies/${companyId}/policies/${policyId}/conflicts`),
  })

  const fix = useMutation({
    mutationFn: (ruleKey: string) =>
      api.post<Envelope<RuleConflict[]>>(`/companies/${companyId}/policies/${policyId}/conflict_fixes`, {
        rule_key: ruleKey,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: conflictsKey })
      void queryClient.invalidateQueries({ queryKey: ['policy', companyId, policyId] })
    },
  })

  const entries = conflicts.data?.data ?? []
  if (entries.length === 0) return null

  return (
    <div>
      <h3 className="mb-2 text-[12px] font-semibold uppercase tracking-wider text-muted-foreground">Conflicts</h3>
      <ul className="space-y-2">
        {entries.map((conflict) => (
          <li
            key={`${conflict.rule_a_key}:${conflict.rule_b_key}`}
            className="rounded border border-warning/40 bg-warning-muted px-3 py-2.5"
          >
            <p className="text-[12.5px]">{conflict.explanation}</p>
            {conflict.fix && canFix && (
              <div className="mt-2 flex flex-wrap items-center gap-2">
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  disabled={fix.isPending}
                  onClick={() => fix.mutate(conflict.fix!.rule_key)}
                >
                  Accept suggested fix
                </Button>
                <span className="text-[12px] text-muted-foreground">
                  Raise {conflict.fix.rule_key} to priority {conflict.fix.new_priority} so it wins.
                </span>
              </div>
            )}
          </li>
        ))}
      </ul>
      {fix.isError && <p className="mt-2 text-[12px] text-destructive">{(fix.error as Error).message}</p>}
    </div>
  )
}
