import { Navigate, useLocation } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useCurrentPerson } from '../../lib/auth'
import { useWorkspace } from '../../lib/workspace'
import { Shell } from '../layout/shell'
import { LoginView } from './login-view'

function Centered({ children }: { children: ReactNode }) {
  return <div className="flex min-h-screen items-center justify-center text-[13px] text-muted-foreground">{children}</div>
}

// The backend says which company this deployment serves. With none yet the
// only place to go is /assemble, which then needs no sign-in (nobody exists
// to sign in). Once a company exists everything needs a real sign-in — except
// /assemble while that company is still assembling, so its live progress
// stays on screen.
export function AuthGate({ children }: { children: ReactNode }) {
  const location = useLocation()
  const workspace = useWorkspace()
  const company = workspace.data?.data?.company
  const onAssemble = location.pathname.startsWith('/assemble')
  const bypass = !company || (onAssemble && company.assembling)

  const sessionQuery = useCurrentPerson(company && !bypass ? String(company.id) : null)

  if (workspace.isPending) {
    return <Centered>Loading…</Centered>
  }

  if (workspace.isError) {
    return <Centered>Keel can't reach its server. Try again in a moment.</Centered>
  }

  if (!company) {
    return onAssemble ? <Shell>{children}</Shell> : <Navigate to="/assemble" />
  }

  if (bypass) {
    return <Shell>{children}</Shell>
  }

  if (sessionQuery.isPending) {
    return <Centered>Checking your session…</Centered>
  }

  if (sessionQuery.isError) {
    return <LoginView companyId={String(company.id)} />
  }

  return <Shell>{children}</Shell>
}
