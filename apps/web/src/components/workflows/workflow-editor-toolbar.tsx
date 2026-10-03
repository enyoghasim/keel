import type { WorkflowStepType } from 'api-types'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'

// Approval is deliberately absent — it's policy-owned (AGENTS.md rule 2),
// never something a human adds here.
export function WorkflowEditorToolbar({ onAdd }: { onAdd: (type: WorkflowStepType) => void }) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button type="button" variant="outline" size="sm">
          + Add step
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        <DropdownMenuItem onSelect={() => onAdd('task')}>Task — someone marks it done</DropdownMenuItem>
        <DropdownMenuItem onSelect={() => onAdd('notify')}>Notify — a heads-up, logged or sent</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
