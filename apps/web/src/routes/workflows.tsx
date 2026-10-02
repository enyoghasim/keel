import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { WorkflowsView } from '../components/workflows/workflows-view'
import { useCompanyId } from '../lib/workspace'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/workflows',
  component: WorkflowsPage,
})

function WorkflowsPage() {
  const companyId = useCompanyId()

  return (
    <>
      <PageHeader
        title="Workflows"
        subtitle="How a request moves from submission to done. Steps use role references, resolved when each becomes active."
      />
      {companyId ? (
        <WorkflowsView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
