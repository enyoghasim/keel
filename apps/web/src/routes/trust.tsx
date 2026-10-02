import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { TrustView } from '../components/trust/trust-view'
import { useCompanyId } from '../lib/workspace'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/trust',
  component: TrustPage,
})

function TrustPage() {
  const companyId = useCompanyId()

  return (
    <>
      <PageHeader
        title="Trust"
        subtitle="How well the AI parts actually work, measured — and where human corrections become new tests."
      />
      {companyId ? (
        <TrustView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
