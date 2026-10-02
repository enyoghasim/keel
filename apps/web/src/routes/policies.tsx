import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { PoliciesView } from '../components/policies/policies-view'
import { useCompanyId } from '../lib/workspace'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/policies',
  component: PoliciesPage,
})

function PoliciesPage() {
  const companyId = useCompanyId()

  return (
    <>
      <PageHeader
        title="Policies"
        subtitle="The handbook and the rules compiled from it, side by side."
      />
      {companyId ? (
        <PoliciesView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
