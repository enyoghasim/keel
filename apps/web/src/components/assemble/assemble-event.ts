// Mirrors AssembleJob's broadcast format (SPEC.md section 6 "Event format",
// apps/api/app/jobs/assemble_job.rb). `data`'s shape depends on `event`; kept
// loose here since this is a display-only concern, not a stored contract.
export interface AssembleEvent {
  /** Position in the company's event log; absent only on events a test makes up. */
  seq?: number
  stage: 'csv' | 'graph' | 'handbook' | 'policies' | 'workflows'
  event: string
  data: Record<string, unknown>
  progress: number
}

/**
 * The log the API kept plus the events that arrived live: the same event can
 * be in both (it was stored, then broadcast to a subscriber that had also
 * fetched), so numbered events are de-duplicated by `seq` and kept in order.
 */
export function mergeEvents(log: AssembleEvent[], live: AssembleEvent[]): AssembleEvent[] {
  const bySeq = new Map<number, AssembleEvent>()
  const unnumbered: AssembleEvent[] = []

  for (const event of [...log, ...live]) {
    if (event.seq == null) unnumbered.push(event)
    else bySeq.set(event.seq, event)
  }

  return [...[...bySeq.entries()].sort(([a], [b]) => a - b).map(([, event]) => event), ...unnumbered]
}
