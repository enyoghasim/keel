import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { RequestsView } from '../components/requests/requests-view'
import { useCompanyId } from '../lib/workspace'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/requests',
  component: RequestsPage,
})

function RequestsPage() {
  const companyId = useCompanyId()

  return (
    <>
      <PageHeader title="My Requests" subtitle="Leave, expense and equipment requests you've submitted, and where each stands." />
      {companyId ? (
        <RequestsView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
