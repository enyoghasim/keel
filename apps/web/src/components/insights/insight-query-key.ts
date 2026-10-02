// Shared by InsightsView (seeding the cache after a POST) and
// InsightAnswer (reading it and applying InsightChannel updates).
export function insightQueryKey(companyId: string, insightId: number) {
  return ['insight', companyId, insightId] as const
}
