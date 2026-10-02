import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/PageHeader'
import { PagePlaceholder } from '../components/layout/PagePlaceholder'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/proposals',
  component: ProposalsPage,
})

function ProposalsPage() {
  return (
    <>
      <PageHeader
        title="Proposals"
        subtitle="Every AI-proposed change, with a computed impact report. Nothing applies until a human approves it."
      />
      <PagePlaceholder note="Impact summary and diff views land once ChangeProposal and Impact::Analyzer exist." />
    </>
  )
}
