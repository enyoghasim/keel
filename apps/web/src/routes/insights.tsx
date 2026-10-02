import { createRoute } from '@tanstack/react-router'
import { InsightsView } from '../components/insights/insights-view'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { getCurrentCompanyId } from '../lib/current-company'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/insights',
  component: InsightsPage,
})

function InsightsPage() {
  const companyId = getCurrentCompanyId()

  return (
    <>
      <PageHeader title="Insights" subtitle="Ask a question in plain language — see exactly how Keel understood it." />
      {companyId ? (
        <InsightsView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
