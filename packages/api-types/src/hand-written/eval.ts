// Mirrors EvalRun#as_payload and EvalResult#as_payload
// (apps/api/app/models/eval_run.rb, eval_result.rb) — what
// Api::EvalRunsController renders and EvalChannel broadcasts.
export type EvalSuite = 'policy_extraction' | 'agent' | 'insights'
export type EvalRunStatus = 'pending' | 'running' | 'completed' | 'failed'

export interface EvalRun {
  id: number
  person_id: number | null
  suite: EvalSuite
  status: EvalRunStatus
  model: string | null
  prompt_version_id: number | null
  accuracy: number | null
  // Mean pairwise behavioural agreement of repeated compiles (policy_extraction, when sampled).
  stability: number | null
  stability_samples: number
  // Mean of the judge's 1-5 rubric scores (agent suite) and how closely it agrees with hand labels.
  judge_score: number | null
  judge_agreement: number | null
  cost_usd: number | null
  cases_count: number
  passed_count: number
  started_at: string | null
  finished_at: string | null
  error_message: string | null
  created_at: string
}

// One field the scorer compared and found different (Evals::InsightsScorer).
// policy_extraction entries may also carry the probe the rules disagreed on.
export interface EvalDiffEntry {
  field: string
  expected?: unknown
  actual?: unknown
  probe?: Record<string, unknown>
  rule?: string
}

export interface EvalResultMetrics {
  behaviour?: number
  quotes_verified?: number
  ambiguity_recall?: number
  probes?: number
  stability?: number
  judge?: { correctness: number; citation: number; clarity: number; no_false_claims: number; mean: number }
  judge_rationale?: string
  judge_agreement?: number
  cost_usd?: number
}

export interface EvalResult {
  id: number
  eval_case_id: number
  case_key: string
  input: Record<string, unknown>
  expected: Record<string, unknown>
  passed: boolean
  score: number | null
  metrics: EvalResultMetrics
  actual: Record<string, unknown> | null
  diff: EvalDiffEntry[]
  latency_ms: number | null
  error_message: string | null
}

export interface EvalRunWithResults extends EvalRun {
  results: EvalResult[]
}

// Api::EvalRunsController#index's `meta`.
export interface EvalRunsMeta {
  active_cases: Partial<Record<EvalSuite, number>>
  runnable_suites: EvalSuite[]
}

// What EvalChannel sends: the run on subscribe, start and finish, and
// each case's result as EvalRunJob scores it.
export type EvalChannelEvent =
  | { event: 'run'; run: EvalRun }
  | { event: 'result'; result: EvalResult; done: number; total: number }

export type EvalCaseSource = 'manual' | 'generated' | 'override'
export type EvalCaseStatus = 'active' | 'candidate' | 'archived'

// Api::EvalCasesController::FIELDS — the review queue lists candidates.
export interface EvalCase {
  id: number
  suite: EvalSuite
  key: string
  input: Record<string, unknown>
  expected: Record<string, unknown>
  source: EvalCaseSource
  status: EvalCaseStatus
  notes: string | null
  created_at: string
}

// Api::PromptVersionsController: `latest_run` is the version's latest
// completed eval run; `regressions` the case keys it would regress against
// the active version (null when it hasn't been evaluated yet).
export interface PromptVersion {
  id: number
  key: string
  version: number
  model: string | null
  active: boolean
  notes: string | null
  created_at: string
  template?: string
  latest_run: EvalRun | null
  regressions: string[] | null
}
