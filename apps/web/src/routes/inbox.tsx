import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/PageHeader'
import { PagePlaceholder } from '../components/layout/PagePlaceholder'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/inbox',
  component: InboxPage,
})

function InboxPage() {
  return (
    <>
      <PageHeader title="Inbox" subtitle="Approvals and tasks waiting on the acting person." />
      <PagePlaceholder note="The step-run list lands once Workflows::Runtime.act and step_runs exist." />
    </>
  )
}
