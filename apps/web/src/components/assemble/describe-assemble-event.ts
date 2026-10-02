import type { AssembleEvent } from './assemble-event'

export function describeAssembleEvent(event: AssembleEvent): string {
  switch (event.event) {
    case 'mapping_complete': {
      const mappings = event.data.mappings as unknown[]
      return `Mapped ${mappings.length} columns`
    }
    case 'person_added': {
      const department = event.data.department as string | null
      return department ? `${event.data.name} added to ${department}` : `${event.data.name} added`
    }
    case 'chunks_embedded':
      return `Embedded ${event.data.count} handbook chunks`
    case 'rule_extracted':
      return `Extracted rule "${event.data.key}" (${event.data.category})`
    case 'workflow_generated':
      return `Generated the ${event.data.request_kind} workflow`
    default:
      return event.event
  }
}
