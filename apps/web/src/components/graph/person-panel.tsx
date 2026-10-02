import type { Department, Person } from 'api-types'
import { PagePlaceholder } from '../layout/page-placeholder'

function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('')
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 text-[13.5px]">{value}</dd>
    </div>
  )
}

export function PersonPanel({
  person,
  department,
  manager,
}: {
  person: Person | null
  department: Department | null
  manager: Person | null
}) {
  if (!person) {
    return (
      <div className="w-72 shrink-0">
        <PagePlaceholder note="Select a person on the chart to see their details." />
      </div>
    )
  }

  return (
    <div className="w-72 shrink-0 rounded-lg border border-border bg-card p-4">
      <div className="flex items-center gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-border-strong bg-muted text-[13px] font-semibold">
          {initials(person.name)}
        </div>
        <div className="min-w-0">
          <h3 className="truncate text-[15px] font-semibold">{person.name}</h3>
          <p className="truncate text-[12.5px] text-muted-foreground">{person.email}</p>
        </div>
      </div>

      <dl className="mt-4 space-y-3">
        <Field label="Title" value={person.title ?? 'No title'} />
        <Field label="Department" value={department?.name ?? 'No department'} />
        <Field label="Manager" value={manager?.name ?? 'No manager'} />
        {person.location && <Field label="Location" value={person.location} />}
        {person.start_date && <Field label="Start date" value={person.start_date} />}
      </dl>

      {person.roles.length > 0 && (
        <div className="mt-4">
          <dt className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">Roles</dt>
          <div className="mt-1.5 flex flex-wrap gap-1.5">
            {person.roles.map((role) => (
              <span
                key={role}
                className="rounded border border-border-strong bg-secondary px-1.5 py-0.5 text-[11.5px] font-medium"
              >
                {role}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
