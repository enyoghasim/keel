// Mirrors Api::ChangeProposalsController::FIELDS and its #serialize_impact
// (apps/api/app/controllers/api/change_proposals_controller.rb). Only "org"
// diffs are implemented end to end today (SPEC.md section 10) — "rule" and
// "workflow" kinds exist as statuses but have no diff shape wired up yet,
// so OrgDiffOp is the only diff type, not ChangeProposal["diff"] in general.
//
// This isn't generated from packages/schemas: that pipeline is for shapes
// an LLM is allowed to produce, and change_proposals is a plain Rails
// resource (ActiveRecord model + controller), not LLM-validated output.
export type OrgDiffOp =
  | { op: 'change_manager'; person_id: number; from?: number; to: number | null }
  | { op: 'set_department_head'; department_id: number; to: number | null }
  | { op: 'assign_role'; person_id: number; role: string }

// Mirrors Rules::Engine::Decision (apps/api/app/services/rules/engine.rb).
export interface Decision {
  outcome: 'auto_approve' | 'require_approval' | 'reject' | 'blocked'
  rule_keys: string[]
  approvers: number[]
  errors: string[]
  explanation: string | null
}

export interface ImpactClassification {
  person_id: number
  before: Decision
  after: Decision
}

export interface ApprovalLoadChange {
  approver_id: number
  before: number
  after: number
}

export interface ReroutedInFlight {
  step_run_id: number
  before_person_ids: number[]
  after_person_ids: number[]
}

// Mirrors Impact::Analyzer::Report via #serialize_impact.
export interface ImpactReport {
  rerouted: ImpactClassification[]
  broken: ImpactClassification[]
  self_approval: ImpactClassification[]
  approval_load_changes: ApprovalLoadChange[]
  rerouted_in_flight: ReroutedInFlight[]
  override_reason?: string
}

export type ChangeProposalKind = 'org' | 'rule' | 'workflow'
export type ChangeProposalStatus = 'pending' | 'approved' | 'rejected'

export interface ChangeProposal {
  id: number
  company_id: number
  kind: ChangeProposalKind
  title: string
  diff: OrgDiffOp[]
  impact: ImpactReport
  proposed_by: 'agent' | 'user'
  status: ChangeProposalStatus
  decided_by_id: number | null
  decided_at: string | null
  created_at: string
}
