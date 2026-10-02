import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/PageHeader'
import { PagePlaceholder } from '../components/layout/PagePlaceholder'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/insights',
  component: InsightsPage,
})

function InsightsPage() {
  return (
    <>
      <PageHeader title="Insights" subtitle="Ask a question in plain language — see exactly how Keel understood it." />
      <PagePlaceholder note="The question box and charts land once Insights::Interpreter and QueryBuilder exist." />
    </>
  )
}
