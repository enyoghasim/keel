import { Navigate, createRoute } from '@tanstack/react-router'
import { useWorkspace } from '../lib/workspace'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  component: IndexPage,
})

// The backend decides where a fresh browser lands: the graph once a company
// exists (AuthGate asks for a sign-in first), Assemble while there is none.
function IndexPage() {
  const company = useWorkspace().data?.data?.company
  return <Navigate to={company ? '/graph' : '/assemble'} replace />
}
