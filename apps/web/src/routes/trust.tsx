import { createRoute } from '@tanstack/react-router'
import { PageHeader } from '../components/layout/PageHeader'
import { PagePlaceholder } from '../components/layout/PagePlaceholder'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/trust',
  component: TrustPage,
})

function TrustPage() {
  return (
    <>
      <PageHeader
        title="Trust"
        subtitle="How well the AI parts actually work, measured — and where human corrections become new tests."
      />
      <PagePlaceholder note="The scoreboard and prompt comparison land once Evals::Runner and eval_runs exist." />
    </>
  )
}
