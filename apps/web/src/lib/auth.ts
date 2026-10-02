import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, SessionPerson, SignInParams } from 'api-types'
import { api } from './api'

function sessionQueryKey(companyId: string | null) {
  return ['session', companyId] as const
}

// Disabled (no fetch at all) when there's no company yet, or the caller
// wants to bypass the check (see AuthGate skipping it on /assemble).
//
// staleTime is Infinity because sign-in/sign-out explicitly update this
// query's cache (setQueryData / invalidateQueries) — without it, every page
// that renders a second useCurrentPerson observer (Topbar, AuthGate) would
// trigger React Query's default refetch-on-mount and silently re-check the
// session on every navigation.
export function useCurrentPerson(companyId: string | null) {
  return useQuery({
    queryKey: sessionQueryKey(companyId),
    queryFn: () => api.get<Envelope<SessionPerson>>(`/companies/${companyId}/session`),
    enabled: companyId !== null,
    staleTime: Infinity,
    retry: false,
  })
}

export function useSignIn(companyId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: SignInParams) => api.post<Envelope<SessionPerson>>(`/companies/${companyId}/session`, params),
    onSuccess: (response) => queryClient.setQueryData(sessionQueryKey(companyId), response),
  })
}

export function useSignOut(companyId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: () => api.delete<Envelope<null>>(`/companies/${companyId}/session`),
    // Removed rather than invalidated: a background refetch of a query that
    // already has data keeps serving that stale data through a 401 (React
    // Query's stale-while-revalidate behaviour), which would leave the old
    // person showing. Removing it forces a clean refetch from "no data".
    onSuccess: () => queryClient.removeQueries({ queryKey: sessionQueryKey(companyId) }),
  })
}
