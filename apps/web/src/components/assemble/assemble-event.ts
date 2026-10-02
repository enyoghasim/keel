// Mirrors AssembleJob's broadcast format (SPEC.md section 6 "Event format",
// apps/api/app/jobs/assemble_job.rb). `data`'s shape depends on `event`; kept
// loose here since this is a display-only concern, not a stored contract.
export interface AssembleEvent {
  stage: 'csv' | 'graph' | 'handbook' | 'policies' | 'workflows'
  event: string
  data: Record<string, unknown>
  progress: number
}
