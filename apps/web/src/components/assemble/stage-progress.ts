import type { AssembleEvent } from './assemble-event'

export interface Stage {
  key: AssembleEvent['stage']
  label: string
  ceiling: number
}

// Labels and progress ceilings from SPEC.md section 6's five stages and the
// `progress` values AssembleJob broadcasts at the end of each
// (apps/api/app/jobs/assemble_job.rb).
export const STAGES: Stage[] = [
  { key: 'csv', label: 'CSV mapping', ceiling: 0.1 },
  { key: 'graph', label: 'Graph building', ceiling: 0.4 },
  { key: 'handbook', label: 'Handbook chunking', ceiling: 0.5 },
  { key: 'policies', label: 'Policy extraction', ceiling: 0.8 },
  { key: 'workflows', label: 'Workflow generation', ceiling: 1 },
]

export type StageStatus = 'pending' | 'active' | 'done'

export function stageStatus(stage: Stage, events: AssembleEvent[]): StageStatus {
  const latest = events[events.length - 1]
  if (!latest) return 'pending'

  const latestIndex = STAGES.findIndex((s) => s.key === latest.stage)
  const thisIndex = STAGES.findIndex((s) => s.key === stage.key)

  if (thisIndex < latestIndex) return 'done'
  if (thisIndex > latestIndex) return 'pending'
  return latest.progress >= stage.ceiling ? 'done' : 'active'
}

export function isComplete(events: AssembleEvent[]): boolean {
  const latest = events[events.length - 1]
  return latest != null && latest.progress >= 1
}

export interface AssembleSummary {
  people: number
  departments: number
  policies: number
  rules: number
  workflows: number
}

export function summarize(events: AssembleEvent[]): AssembleSummary {
  const departments = new Set<string>()
  const policies = new Set<unknown>()
  let people = 0
  let rules = 0
  let workflows = 0

  for (const event of events) {
    switch (event.event) {
      case 'person_added':
        people += 1
        if (event.data.department) departments.add(event.data.department as string)
        break
      case 'rule_extracted':
        rules += 1
        policies.add(event.data.policy_id)
        break
      case 'workflow_generated':
        workflows += 1
        break
    }
  }

  return { people, departments: departments.size, policies: policies.size, rules, workflows }
}
