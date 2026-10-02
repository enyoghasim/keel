export function PagePlaceholder({ note }: { note: string }) {
  return (
    <div className="rounded-lg border border-dashed border-border-strong bg-card px-6 py-16 text-center text-[13px] text-muted-foreground">
      {note}
    </div>
  )
}
