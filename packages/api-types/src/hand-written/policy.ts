import type { Action, Ambiguity, Condition } from '../generated/policy-rules'

// Mirrors Api::PoliciesController::FIELDS (apps/api/app/controllers/api/policies_controller.rb)
// and the Policy model's CATEGORIES/STATUSES.
export type PolicyCategory = 'leave' | 'expense' | 'remote' | 'equipment' | 'onboarding'
export type PolicyStatus = 'draft' | 'active' | 'needs_review' | 'superseded'

export interface Policy {
  id: number
  title: string
  category: PolicyCategory
  status: PolicyStatus
  version: number
  created_at: string
}

// What Api::PoliciesController#show returns: a Policy with its rules merged in.
export interface PolicyWithRules extends Policy {
  rules: Rule[]
}

// Mirrors Api::RulesController::FIELDS (apps/api/app/controllers/api/rules_controller.rb)
// and the Rule model's STATUSES. Note there's no source_chunk/page exposed here yet —
// only the verbatim source_quote.
export type RuleStatus = 'extracted' | 'resolved' | 'active' | 'superseded'

export interface Rule {
  id: number
  key: string
  conditions: Condition
  actions: Action
  priority: number
  source_quote: string
  ambiguities: Ambiguity[]
  status: RuleStatus
  policy_id: number
}

// Mirrors Rules::Engine::Decision as rendered by Api::PoliciesController#test
// (apps/api/app/controllers/api/policies_controller.rb).
export interface PolicyTestResult {
  outcome: 'auto_approve' | 'require_approval' | 'reject' | 'blocked'
  matched_rule_keys: string[]
  approvers: number[]
  errors: string[]
  explanation: string | null
}
