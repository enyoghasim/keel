import { Outlet, createRootRoute } from '@tanstack/react-router'
import { AuthGate } from '../components/auth/auth-gate'

export const Route = createRootRoute({
  component: () => (
    <AuthGate>
      <Outlet />
    </AuthGate>
  ),
})
