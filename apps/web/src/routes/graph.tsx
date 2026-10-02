import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/graph',
  component: GraphPage,
})

function GraphPage() {
  return (
    <>
      <PageHeader
        title="Graph"
        subtitle="The company graph — people, departments, managers and roles."
      />
      <PagePlaceholder note="OrgCanvas lands once Org::GraphSnapshot and the people/departments endpoints exist." />
    </>
  )
}
