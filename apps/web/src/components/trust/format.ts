export function formatAccuracy(accuracy: number | null) {
  return accuracy === null ? '—' : `${Math.round(accuracy * 1000) / 10}%`
}

export function formatRunDate(iso: string) {
  return new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

export const SUITE_LABELS = {
  insights: 'Insights',
  policy_extraction: 'Policy extraction',
  agent: 'Agent',
} as const
