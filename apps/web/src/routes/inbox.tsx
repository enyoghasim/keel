import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/page-header'
import { PagePlaceholder } from '../components/layout/page-placeholder'
import { InboxView } from '../components/inbox/inbox-view'
import { getCurrentCompanyId } from '../lib/current-company'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/inbox',
  component: InboxPage,
})

function InboxPage() {
  const companyId = getCurrentCompanyId()

  return (
    <>
      <PageHeader title="Inbox" subtitle="Approvals and tasks waiting on you." />
      {companyId ? (
        <InboxView companyId={companyId} />
      ) : (
        <PagePlaceholder note="No company yet — assemble one on the Assemble page first." />
      )}
    </>
  )
}
