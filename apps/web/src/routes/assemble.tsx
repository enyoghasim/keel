import { createRoute } from '@tanstack/react-router'
import { AssembleView } from '../components/assemble/assemble-view'
import { PageHeader } from '../components/layout/page-header'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/assemble',
  component: AssemblePage,
})

function AssemblePage() {
  return (
    <>
      <PageHeader
        title="Assemble"
        subtitle="Upload a messy CSV and a handbook PDF. The org chart and policies assemble themselves live on screen."
      />
      <AssembleView />
    </>
  )
}
