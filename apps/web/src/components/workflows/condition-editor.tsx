import type { Condition } from 'api-types'
import { describeCondition } from '../policies/describe-rule'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

type Field = Condition extends infer T ? (T extends { field: infer F } ? F : never) : never
type Op = Condition extends infer T ? (T extends { op: infer O } ? O : never) : never
type Leaf = Extract<Condition, { field: string }>

const FIELDS: { value: Field; label: string; kind: 'string' | 'number' }[] = [
  { value: 'requester.department', label: 'Department', kind: 'string' },
  { value: 'requester.location', label: 'Location', kind: 'string' },
  { value: 'requester.tenure_months', label: 'Tenure (months)', kind: 'number' },
  { value: 'payload.amount_eur', label: 'Amount (EUR)', kind: 'number' },
  { value: 'payload.category', label: 'Category', kind: 'string' },
  { value: 'payload.days', label: 'Days', kind: 'number' },
  { value: 'payload.notice_days', label: 'Notice days', kind: 'number' },
]

const OPS: { value: Op; label: string }[] = [
  { value: 'eq', label: 'is' },
  { value: 'neq', label: 'is not' },
  { value: 'gt', label: '>' },
  { value: 'gte', label: '≥' },
  { value: 'lt', label: '<' },
  { value: 'lte', label: '≤' },
  { value: 'in', label: 'is one of' },
  { value: 'not_in', label: 'is not one of' },
  { value: 'between', label: 'is between' },
]

const DEFAULT_LEAF: Leaf = { field: 'payload.amount_eur', op: 'gt', value: 0 }

function fieldKind(field: Field) {
  return FIELDS.find((f) => f.value === field)?.kind ?? 'string'
}

function castValue(raw: string, kind: 'string' | 'number'): string | number {
  if (kind !== 'number') return raw
  const parsed = Number(raw)
  return Number.isNaN(parsed) ? 0 : parsed
}

/**
 * A single field/op/value row for a workflow step's `when` condition — no
 * nested all/any builder; a workflow step only ever needs one comparison
 * (SPEC.md section 8). Reuses describeCondition for a live, plain-English
 * preview underneath, the same rendering the read-only edge label uses.
 */
export function ConditionEditor({ condition, onChange }: { condition: Leaf | undefined; onChange: (condition: Leaf | undefined) => void }) {
  const leaf = condition ?? DEFAULT_LEAF
  const kind = fieldKind(leaf.field as Field)

  function update(patch: Partial<Leaf>) {
    onChange({ ...leaf, ...patch } as Leaf)
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <label className="flex items-center gap-1.5 text-[12px]">
          <input
            type="checkbox"
            checked={condition !== undefined}
            onChange={(event) => onChange(event.target.checked ? leaf : undefined)}
          />
          Only when
        </label>
      </div>

      {condition !== undefined && (
        <>
          <div className="grid grid-cols-3 gap-1.5">
            <Select value={leaf.field} onValueChange={(value) => update({ field: value as Field, value: fieldKind(value as Field) === 'number' ? 0 : '' })}>
              <SelectTrigger aria-label="Condition field">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {FIELDS.map((f) => (
                  <SelectItem key={f.value} value={f.value}>
                    {f.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Select value={leaf.op} onValueChange={(value) => update({ op: value as Op })}>
              <SelectTrigger aria-label="Condition operator">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {OPS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            {leaf.op === 'between' ? (
              <div className="flex items-center gap-1">
                <input
                  type="number"
                  aria-label="From"
                  value={Array.isArray(leaf.value) ? String(leaf.value[0] ?? '') : ''}
                  onChange={(event) => update({ value: [ castValue(event.target.value, 'number'), Array.isArray(leaf.value) ? leaf.value[1] : 0 ] })}
                  className="w-full rounded border border-border bg-background px-2 py-1.5 text-[13px]"
                />
                <input
                  type="number"
                  aria-label="To"
                  value={Array.isArray(leaf.value) ? String(leaf.value[1] ?? '') : ''}
                  onChange={(event) => update({ value: [ Array.isArray(leaf.value) ? leaf.value[0] : 0, castValue(event.target.value, 'number') ] })}
                  className="w-full rounded border border-border bg-background px-2 py-1.5 text-[13px]"
                />
              </div>
            ) : leaf.op === 'in' || leaf.op === 'not_in' ? (
              <input
                type="text"
                aria-label="Values, comma-separated"
                placeholder="a, b, c"
                value={Array.isArray(leaf.value) ? leaf.value.join(', ') : ''}
                onChange={(event) =>
                  update({ value: event.target.value.split(',').map((v) => castValue(v.trim(), kind)) })
                }
                className="w-full rounded border border-border bg-background px-2 py-1.5 text-[13px]"
              />
            ) : (
              <input
                type={kind === 'number' ? 'number' : 'text'}
                aria-label="Condition value"
                value={typeof leaf.value === 'object' ? '' : String(leaf.value)}
                onChange={(event) => update({ value: castValue(event.target.value, kind) })}
                className="w-full rounded border border-border bg-background px-2 py-1.5 text-[13px]"
              />
            )}
          </div>
          <p className="text-[11.5px] text-muted-foreground">{describeCondition(leaf)}</p>
        </>
      )}
    </div>
  )
}
