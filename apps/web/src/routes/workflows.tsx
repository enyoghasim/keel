import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/workflows',
  component: WorkflowsPage,
})

function WorkflowsPage() {
  return (
    <>
      <PageHeader
        title="Workflows"
        subtitle="How a request moves from submission to done. Steps use role references, resolved when each becomes active."
      />
      <PagePlaceholder note="FlowCanvas lands once Workflows::Runtime and the workflow steps endpoint exist." />
    </>
  )
}
