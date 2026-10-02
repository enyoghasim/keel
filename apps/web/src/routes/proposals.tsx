import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/PageHeader'
import { PagePlaceholder } from '../components/layout/PagePlaceholder'
import { ProposalsView } from '../components/proposals/ProposalsView'
import { getCurrentCompanyId } from '../lib/currentCompany'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/proposals',
  component: ProposalsPage,
})

function ProposalsPage() {
  const companyId = getCurrentCompanyId()

  return (
    <>
      <PageHeader
        title="Proposals"
        subtitle="Every AI-proposed change, with a computed impact report. Nothing applies until a human approves it."
      />
      {companyId ? (
        <ProposalsView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
