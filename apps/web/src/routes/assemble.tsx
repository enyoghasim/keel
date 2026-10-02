import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/PageHeader'
import { PagePlaceholder } from '../components/layout/PagePlaceholder'
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
      <PagePlaceholder note="Assemble pipeline UI lands once Assemble::CsvMapper and the AssembleChannel events exist." />
    </>
  )
}
