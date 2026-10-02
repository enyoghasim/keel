export function evalRunsQueryKey(companyId: string) {
  return ['eval_runs', companyId] as const
}

export function evalRunQueryKey(companyId: string, runId: number) {
  return ['eval_run', companyId, runId] as const
}

export function promptVersionsQueryKey(companyId: string) {
  return ['prompt_versions', companyId] as const
}

export function candidateCasesQueryKey(companyId: string) {
  return ['eval_cases', companyId, 'candidate'] as const
}
