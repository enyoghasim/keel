// Mirrors Api::RequestsController::FIELDS and its #serialize/#serialize_workflow_run
// (apps/api/app/controllers/api/requests_controller.rb), and Api::StepRunsController::FIELDS
// (apps/api/app/controllers/api/step_runs_controller.rb) for the nested step runs.
//
// Workflows::Runtime (apps/api/app/services/workflows/runtime.rb) resolves one step at a
// time: a step_run is actually actionable once it has both status "pending" and a
// resolved_person_id — until then it exists but hasn't been assigned yet.
export type StepRunStatus = 'pending' | 'done' | 'rejected' | 'cancelled'

export interface StepRun {
  id: number
  step_key: string
  reference: string | null
  resolved_person_id: number | null
  status: StepRunStatus
  acted_at: string | null
  overridden: boolean
  override_reason: string | null
}

export type WorkflowRunStatus = 'in_progress' | 'done' | 'rejected'

export interface WorkflowRun {
  id: number
  status: WorkflowRunStatus
  current_step: string | null
  step_runs: StepRun[]
}

export type RequestStatus = 'pending' | 'approved' | 'rejected' | 'blocked'

export interface Request {
  id: number
  company_id: number
  requester_id: number
  kind: string
  payload: Record<string, unknown>
  decision: string | null
  matched_rule_ids: string[]
  policy_version: number | null
  status: RequestStatus
  created_at: string
  workflow_run: WorkflowRun | null
}
