function SummaryCard({ label, value, danger }: { label: string; value: number; danger?: boolean }) {
  const isAlarmed = danger && value > 0
  return (
    <div
      className={
        isAlarmed
          ? 'rounded-lg border border-destructive-muted bg-destructive-muted px-4 py-3'
          : 'rounded-lg border border-border bg-card px-4 py-3'
      }
    >
      <div className={`text-2xl font-bold tabular-nums ${isAlarmed ? 'text-destructive' : 'text-foreground'}`}>
        {value}
      </div>
      <div className="text-[12px] text-muted-foreground">{label}</div>
    </div>
  )
}

export function ImpactSummaryCards({
  rerouted,
  broken,
  selfApproval,
}: {
  rerouted: number
  broken: number
  selfApproval: number
}) {
  return (
    <div className="grid grid-cols-3 gap-3">
      <SummaryCard label="Rerouted" value={rerouted} />
      <SummaryCard label="Broken" value={broken} danger />
      <SummaryCard label="Self-approval" value={selfApproval} danger />
    </div>
  )
}
