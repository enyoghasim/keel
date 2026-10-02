import type { Condition } from '../generated/policy-rules'

// Mirrors Api::WorkflowsController::FIELDS (apps/api/app/controllers/api/workflows_controller.rb)
// and the Workflow model's STATUSES.
export type WorkflowStatus = 'draft' | 'active' | 'superseded'

export interface WorkflowTrigger {
  request_kind: string
}

// A step's shape depends on its type: approval steps carry no `assignee` —
// their approvers come from the matched rule's decision at runtime, not
// from the workflow definition (SPEC.md section 8). Task/notify steps
// resolve `assignee`, a role or org reference, the same way.
export type WorkflowStepType = 'approval' | 'task' | 'notify'

export interface WorkflowStep {
  key: string
  type: WorkflowStepType
  title?: string
  assignee?: string
  when?: Condition
}

export interface Workflow {
  id: number
  name: string
  status: WorkflowStatus
  trigger: WorkflowTrigger
  steps: WorkflowStep[]
  created_at: string
}

// What Api::WorkflowsController#test_run returns: Workflows::Runtime#dry_run
// resolved against the current org snapshot, nothing persisted. `matched:
// false` means the step's `when` condition didn't fire for this scenario.
export interface WorkflowTestRunStep {
  step_key: string
  type: string
  reference: string | null
  resolved_person_id: number | null
  matched: boolean
}

export interface WorkflowTestRunResult {
  outcome: 'auto_approve' | 'require_approval' | 'reject' | 'blocked'
  matched_rule_keys: string[]
  errors: string[]
  steps: WorkflowTestRunStep[]
}

// Mirrors WorkflowEdit#as_payload: one "Describe a change" instruction and
// what became of it. `proposed` links to the ChangeProposal it produced;
// `unchanged` means the model's workflow was identical to the current one.
export type WorkflowEditStatus = 'pending' | 'proposed' | 'unchanged' | 'failed'

export interface WorkflowEdit {
  id: number
  workflow_id: number
  instruction: string
  status: WorkflowEditStatus
  change_proposal_id: number | null
  error_message: string | null
  created_at: string
}
