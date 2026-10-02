import { useQuery } from '@tanstack/react-query'
import type { Envelope, Workspace } from 'api-types'
import { api } from './api'

export const workspaceQueryKey = ['workspace'] as const

// Which company this deployment serves comes from the backend, not from
// anything the browser remembers. staleTime is Infinity: it only changes
// when Assemble creates the company, which invalidates it.
export function useWorkspace() {
  return useQuery({
    queryKey: workspaceQueryKey,
    queryFn: () => api.get<Envelope<Workspace>>('/workspace'),
    staleTime: Infinity,
    retry: false,
  })
}

/** The served company's id, or null while it loads or when there is none yet. */
export function useCompanyId(): string | null {
  const company = useWorkspace().data?.data?.company
  return company ? String(company.id) : null
}
