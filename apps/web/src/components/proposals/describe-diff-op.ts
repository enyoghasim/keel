import type { Department, OrgDiffOp, Person } from 'api-types'

// Display-only resolution of person_id/department_id to names for a human
// reading a proposal — the stored diff still holds only ids (AGENTS.md rule
// 1: nothing stores a name), this just renders it legibly.
function personLabel(people: Map<number, Person>, id: number | null): string {
  if (id == null) return 'nobody'
  return people.get(id)?.name ?? `Person #${id}`
}

function departmentLabel(departments: Map<number, Department>, id: number): string {
  return departments.get(id)?.name ?? `Department #${id}`
}

export function describeDiffOp(
  op: OrgDiffOp,
  people: Map<number, Person>,
  departments: Map<number, Department>,
): string {
  switch (op.op) {
    case 'change_manager': {
      const to = personLabel(people, op.to)
      const from = op.from != null ? personLabel(people, op.from) : null
      return from
        ? `${personLabel(people, op.person_id)} now reports to ${to} instead of ${from}`
        : `${personLabel(people, op.person_id)} now reports to ${to}`
    }
    case 'set_department_head':
      return `${departmentLabel(departments, op.department_id)}'s head becomes ${personLabel(people, op.to)}`
    case 'move_person':
      return `${personLabel(people, op.person_id)} moves to ${departmentLabel(departments, op.department_id)}`
    case 'assign_role':
      return `${personLabel(people, op.person_id)} is assigned the role "${op.role}"`
  }
}
