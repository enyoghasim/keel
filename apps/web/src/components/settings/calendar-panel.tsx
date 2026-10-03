import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, Integration } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'

const integrationsKey = (companyId: string) => ['integrations', companyId] as const

// GoogleCalendarOauthController#callback redirects back here with
// ?calendar_error=... when the connection failed — read it once, then
// clean the URL so a refresh doesn't keep showing a stale error.
function initialOauthError() {
  const error = new URLSearchParams(window.location.search).get('calendar_error')
  if (error) window.history.replaceState(null, '', window.location.pathname)
  return error
}

/**
 * Connects a company to Google Calendar (SPEC.md section 8's workflow side
 * effects): a task step bound to this integration creates a real event
 * instead of only waiting on a human to mark it done. Full OAuth2 —
 * "Connect" is a real link to the server's /authorize redirect, not a
 * fetch call, since Google's consent screen needs the browser itself.
 */
export function CalendarPanel({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const [oauthError] = useState(initialOauthError)

  const query = useQuery({
    queryKey: integrationsKey(companyId),
    queryFn: () => api.get<Envelope<Integration[]>>(`/companies/${companyId}/integrations`),
  })

  const disconnect = useMutation({
    mutationFn: (id: number) => api.delete<Envelope<null>>(`/companies/${companyId}/integrations/${id}`),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: integrationsKey(companyId) }),
  })

  const calendar = query.data?.data?.find((integration) => integration.kind === 'google_calendar')

  return (
    <Card role="region" aria-label="Google Calendar">
      <div>
        <h2 className="text-[15px] font-semibold">Google Calendar</h2>
        <p className="mt-1 text-[13px] text-muted-foreground">
          A workflow's task step can create a real event here instead of only waiting on a human to mark it done.
        </p>
      </div>

      {calendar ? (
        <div className="flex items-center justify-between gap-3 rounded border border-border bg-secondary px-3 py-2.5">
          <div>
            <p className="text-[13px] font-medium">Connected</p>
            {calendar.error_message && <p className="mt-0.5 text-[12px] text-destructive">{calendar.error_message}</p>}
          </div>
          <Button type="button" variant="outline" size="sm" disabled={disconnect.isPending} onClick={() => disconnect.mutate(calendar.id)}>
            Disconnect
          </Button>
        </div>
      ) : (
        <Button asChild className="self-start">
          <a href={`/api/companies/${companyId}/integrations/google_calendar/authorize`}>Connect Google Calendar</a>
        </Button>
      )}
      {oauthError && <p className="text-[12px] text-destructive">{oauthError}</p>}
      {disconnect.isError && <p className="text-[12px] text-destructive">{(disconnect.error as Error).message}</p>}
    </Card>
  )
}
