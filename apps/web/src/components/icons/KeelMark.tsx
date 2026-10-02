export function KeelMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 256 256" className={className} aria-hidden="true">
      <rect x="50" y="32" width="44" height="192" fill="currentColor" />
      <polygon points="65,115.9 215,28.9 229,53.1 79,140.1" fill="currentColor" />
      <polygon points="79,115.9 229,202.9 215,227.1 65,140.1" fill="currentColor" />
    </svg>
  )
}
