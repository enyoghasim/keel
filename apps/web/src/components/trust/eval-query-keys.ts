export function evalRunsQueryKey(companyId: string) {
  return ['eval_runs', companyId] as const
}

export function evalRunQueryKey(companyId: string, runId: number) {
  return ['eval_run', companyId, runId] as const
}
