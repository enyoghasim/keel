import { createRouter } from '@tanstack/react-router'
import { Route as rootRoute } from './routes/__root'
import { Route as assembleRoute } from './routes/assemble'
import { Route as graphRoute } from './routes/graph'
import { Route as inboxRoute } from './routes/inbox'
import { Route as indexRoute } from './routes/index'
import { Route as insightsRoute } from './routes/insights'
import { Route as policiesRoute } from './routes/policies'
import { Route as proposalsRoute } from './routes/proposals'
import { Route as trustRoute } from './routes/trust'
import { Route as workflowsRoute } from './routes/workflows'

export const routeTree = rootRoute.addChildren([
  indexRoute,
  assembleRoute,
  graphRoute,
  policiesRoute,
  workflowsRoute,
  proposalsRoute,
  inboxRoute,
  insightsRoute,
  trustRoute,
])

export const router = createRouter({ routeTree })

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}
