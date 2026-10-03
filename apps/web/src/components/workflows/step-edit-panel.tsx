import type { Integration, WorkflowStep, WorkflowStepType } from 'api-types'
import { ConditionEditor } from './condition-editor'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetClose, SheetContent, SheetTitle } from '@/components/ui/sheet'

// A role reference (role:it_admin) or org reference (manager_of(requester))
// — mirrors Workflows::StepValidator::REFERENCE (apps/api) so a typo, or a
// still-blank assignee on a newly added step, is caught here instead of
// only after Save.
export const REFERENCE = /^(requester|manager_of\(requester\)|skip_manager_of\(requester\)|head_of\(requester\.department\)|role:\w+|person:\d+)$/

const TYPES: { value: WorkflowStepType; label: string }[] = [
  { value: 'task', label: 'Task' },
  { value: 'notify', label: 'Notify' },
]

/**
 * Edits one task/notify step of a workflow (SPEC.md section 8's editor).
 * Approval steps never open here — they're policy-owned and the toolbar
 * that opens this panel excludes them entirely.
 */
export function StepEditPanel({
  step,
  integrations,
  onChange,
  onDelete,
  onClose,
}: {
  step: WorkflowStep
  integrations: Integration[]
  onChange: (step: WorkflowStep) => void
  onDelete: () => void
  onClose: () => void
}) {
  const connected = integrations.filter((integration) => integration.status === 'connected')
  const assigneeValid = REFERENCE.test(step.assignee ?? '')

  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent aria-label={`Edit ${step.key}`} showCloseButton={false} className="z-60 w-full gap-0 overflow-y-auto sm:max-w-md">
        <div className="flex items-start justify-between gap-3 border-b border-border px-4 py-3">
          <SheetTitle className="text-[14px]">Edit step</SheetTitle>
          <SheetClose asChild>
            <Button variant="ghost" size="icon" aria-label="Close" className="size-7">
              ✕
            </Button>
          </SheetClose>
        </div>

        <div className="space-y-4 px-4 py-4">
          <div className="space-y-1">
            <Label htmlFor="step-type">Type</Label>
            <Select value={step.type} onValueChange={(value) => onChange({ ...step, type: value as WorkflowStepType })}>
              <SelectTrigger id="step-type">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {TYPES.map((t) => (
                  <SelectItem key={t.value} value={t.value}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1">
            <Label htmlFor="step-title">Title</Label>
            <Input id="step-title" value={step.title ?? ''} onChange={(event) => onChange({ ...step, title: event.target.value })} placeholder={step.key} />
          </div>

          <div className="space-y-1">
            <Label htmlFor="step-assignee">Assignee</Label>
            <Input
              id="step-assignee"
              value={step.assignee ?? ''}
              onChange={(event) => onChange({ ...step, assignee: event.target.value })}
              placeholder="role:it_admin or manager_of(requester)"
              aria-invalid={!assigneeValid}
            />
            {!assigneeValid && (
              <p className="text-[11.5px] text-destructive">
                A role reference (role:it_admin) or org reference (manager_of(requester)) — never a person's name.
              </p>
            )}
          </div>

          <div className="space-y-1">
            <Label>Condition</Label>
            <ConditionEditor condition={step.when as never} onChange={(when) => onChange({ ...step, when: when as never })} />
          </div>

          <div className="space-y-1">
            <Label htmlFor="step-integration">Integration</Label>
            <Select
              value={step.integration?.kind ?? 'none'}
              onValueChange={(value) => onChange({ ...step, integration: value === 'none' ? undefined : { kind: value as 'slack' | 'google_calendar' } })}
            >
              <SelectTrigger id="step-integration">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">None — logged only</SelectItem>
                <SelectItem value="slack" disabled={!connected.some((i) => i.kind === 'slack')}>
                  Slack{connected.some((i) => i.kind === 'slack') ? '' : ' (not connected)'}
                </SelectItem>
                <SelectItem value="google_calendar" disabled={!connected.some((i) => i.kind === 'google_calendar')}>
                  Google Calendar{connected.some((i) => i.kind === 'google_calendar') ? '' : ' (not connected)'}
                </SelectItem>
              </SelectContent>
            </Select>
            <p className="text-[11.5px] text-muted-foreground">
              {step.type === 'notify' ? 'Posts a real message when this step fires.' : 'Fires once this step becomes active, alongside waiting for it to be marked done.'}
            </p>
          </div>

          <Button type="button" variant="outline" size="sm" onClick={onDelete} className="text-destructive">
            Delete step
          </Button>
        </div>
      </SheetContent>
    </Sheet>
  )
}
