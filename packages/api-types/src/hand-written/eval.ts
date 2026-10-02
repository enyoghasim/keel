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
  accuracy: number | null
  cases_count: number
  passed_count: number
  started_at: string | null
  finished_at: string | null
  error_message: string | null
  created_at: string
}

// One field the scorer compared and found different (Evals::InsightsScorer).
export interface EvalDiffEntry {
  field: string
  expected: unknown
  actual: unknown
}

export interface EvalResult {
  id: number
  eval_case_id: number
  case_key: string
  input: Record<string, unknown>
  expected: Record<string, unknown>
  passed: boolean
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
