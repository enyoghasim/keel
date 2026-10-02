import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/PageHeader'
import { PagePlaceholder } from '../components/layout/PagePlaceholder'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/policies',
  component: PoliciesPage,
})

function PoliciesPage() {
  return (
    <>
      <PageHeader
        title="Policies"
        subtitle="The handbook and the rules compiled from it, side by side."
      />
      <PagePlaceholder note="Rule cards and the handbook pane land once Rules::Engine and policy extraction exist." />
    </>
  )
}
