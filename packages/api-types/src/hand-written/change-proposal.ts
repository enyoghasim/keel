import type { Action, Condition } from '../generated/policy-rules'
import type { WorkflowStep } from './workflow'

// Mirrors Api::ChangeProposalsController::FIELDS, #serialize_impact's
// replacement Impact::OrgImpact and Impact::RuleImpact (apps/api/app/services/impact/).
// "org" and "rule" proposals are implemented end to end (SPEC.md section 10);
// "workflow" proposals come from a "Describe a change" instruction (WorkflowEditJob).
//
// This isn't generated from packages/schemas: that pipeline is for shapes
// an LLM is allowed to produce, and change_proposals is a plain Rails
// resource (ActiveRecord model + controller), not LLM-validated output.
export type OrgDiffOp =
  | { op: 'change_manager'; person_id: number; from?: number; to: number | null }
  | { op: 'set_department_head'; department_id: number; to: number | null }
  | { op: 'assign_role'; person_id: number; role: string }
  | { op: 'move_person'; person_id: number; department_id: number }

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

// One rule as stored in a rule proposal's diff (Agent::Tools::ProposeRuleChange).
// The rewritten rule keeps its original handbook quote and chunk.
export interface RuleSnapshot {
  key: string
  priority: number
  conditions: Condition
  actions: Action
  source_quote: string
  source_chunk_id: number
}

// Only the rules that change: before[i] and after[i] share a key.
export interface RuleDiff {
  policy_id: number
  instruction: string
  before: RuleSnapshot[]
  after: RuleSnapshot[]
}

export interface BacktestFlip {
  request_id: number | null
  requester_id: number
  payload: Record<string, unknown>
  before: Decision['outcome']
  after: Decision['outcome']
}

// Mirrors Impact::RuleImpact: past requests replayed through the old and
// new rules. `summary` is a template sentence, not LLM text.
export interface RuleImpactReport {
  backtest: {
    kind: string
    total: number
    flipped_count: number
    flipped: BacktestFlip[]
    // Same-priority overlaps the rewrite introduces; `example` is a request that triggers one.
    new_conflicts: { rules: [string, string]; example: Record<string, unknown>; warning: string }[]
    summary: string
  }
}

// Mirrors Impact::WorkflowImpact: the step-level diff plus who is affected
// by dry-running the old and new workflow for every person.
export interface WorkflowImpactStep {
  step_key: string
  reference: string | null
  person_id: number | null
}

export interface WorkflowImpactReport {
  steps: { added: string[]; removed: string[]; changed: string[]; moved: string[] }
  scenarios_run: number
  // People whose matched steps differ in at least one scenario.
  affected_count: number
  // The first few (person, request) pairs, with the steps before and after.
  affected: { person_id: number; payload: Record<string, unknown>; before: WorkflowImpactStep[]; after: WorkflowImpactStep[] }[]
  // New steps that resolve to nobody, and how many people hit each.
  broken: { step_key: string; reference: string | null; person_count: number }[]
  // Open step runs waiting on a step the change removes.
  in_flight: number
  override_reason?: string
}

// Only the steps change: before/after are the whole step lists.
export interface WorkflowDiff {
  workflow_id: number
  request_kind: string
  instruction: string
  before: WorkflowStep[]
  after: WorkflowStep[]
}

export type ChangeProposalKind = 'org' | 'rule' | 'workflow'
export type ChangeProposalStatus = 'pending' | 'approved' | 'rejected'

interface ChangeProposalBase {
  id: number
  company_id: number
  title: string
  proposed_by: 'agent' | 'user'
  // The agent run (trace) that proposed it, when the agent did.
  agent_run_id: number | null
  status: ChangeProposalStatus
  decided_by_id: number | null
  decided_at: string | null
  created_at: string
}

export interface OrgChangeProposal extends ChangeProposalBase {
  kind: 'org'
  diff: OrgDiffOp[]
  impact: ImpactReport
}

export interface RuleChangeProposal extends ChangeProposalBase {
  kind: 'rule'
  diff: RuleDiff
  impact: RuleImpactReport
}

export interface WorkflowChangeProposal extends ChangeProposalBase {
  kind: 'workflow'
  diff: WorkflowDiff
  impact: WorkflowImpactReport
}

export type ChangeProposal = OrgChangeProposal | RuleChangeProposal | WorkflowChangeProposal
