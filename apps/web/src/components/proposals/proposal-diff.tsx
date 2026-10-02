import type { Department, OrgDiffOp, Person } from 'api-types'
import { describeDiffOp } from './describe-diff-op'

export function ProposalDiff({
  diff,
  people,
  departments,
}: {
  diff: OrgDiffOp[]
  people: Map<number, Person>
  departments: Map<number, Department>
}) {
  return (
    <ul className="space-y-1.5 text-[13px]">
      {diff.map((op, index) => (
        <li key={index} className="rounded border border-border bg-secondary px-3 py-2">
          {describeDiffOp(op, people, departments)}
        </li>
      ))}
    </ul>
  )
}
