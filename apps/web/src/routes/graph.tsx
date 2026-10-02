import { createRoute } from '@tanstack/react-router'
import { GraphView } from '../components/graph/graph-view'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { getCurrentCompanyId } from '../lib/current-company'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/graph',
  component: GraphPage,
})

function GraphPage() {
  const companyId = getCurrentCompanyId()

  return (
    <>
      <PageHeader
        title="Graph"
        subtitle="The company graph — people, departments, managers and roles."
      />
      {companyId ? (
        <GraphView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
