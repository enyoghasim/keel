import { useLocation } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useCurrentPerson } from '../../lib/auth'
import { getCurrentCompanyId } from '../../lib/current-company'
import { Shell } from '../layout/shell'
import { LoginView } from './login-view'

// Gates every route behind a real sign-in once a company exists — except
// /assemble, which has to stay reachable with no session at all so a new
// company can be created in the first place.
export function AuthGate({ children }: { children: ReactNode }) {
  const companyId = getCurrentCompanyId()
  const location = useLocation()
  const bypass = companyId === null || location.pathname.startsWith('/assemble')

  const sessionQuery = useCurrentPerson(bypass ? null : companyId)

  if (bypass) {
    return <Shell>{children}</Shell>
  }

  if (sessionQuery.isPending) {
    return <div className="flex min-h-screen items-center justify-center text-[13px] text-muted-foreground">Checking your session…</div>
  }

  if (sessionQuery.isError) {
    return <LoginView companyId={companyId} />
  }

  return <Shell>{children}</Shell>
}
