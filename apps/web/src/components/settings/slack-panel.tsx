import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Envelope, Integration } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const integrationsKey = (companyId: string) => ['integrations', companyId] as const

/**
 * Connects a company to Slack (SPEC.md section 8's workflow side effects):
 * a notify step bound to this integration posts a real message instead of
 * only logging that someone should have been told. Just an incoming
 * webhook URL — no OAuth app to register, usable immediately.
 */
export function SlackPanel({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const [webhookUrl, setWebhookUrl] = useState('')

  const query = useQuery({
    queryKey: integrationsKey(companyId),
    queryFn: () => api.get<Envelope<Integration[]>>(`/companies/${companyId}/integrations`),
  })

  const connect = useMutation({
    mutationFn: () => api.post<Envelope<Integration>>(`/companies/${companyId}/integrations`, { kind: 'slack', webhook_url: webhookUrl }),
    onSuccess: () => {
      setWebhookUrl('')
      void queryClient.invalidateQueries({ queryKey: integrationsKey(companyId) })
    },
  })

  const disconnect = useMutation({
    mutationFn: (id: number) => api.delete<Envelope<null>>(`/companies/${companyId}/integrations/${id}`),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: integrationsKey(companyId) }),
  })

  const slack = query.data?.data?.find((integration) => integration.kind === 'slack')

  return (
    <Card role="region" aria-label="Slack">
      <div>
        <h2 className="text-[15px] font-semibold">Slack</h2>
        <p className="mt-1 text-[13px] text-muted-foreground">
          A workflow's notify step can post here instead of only logging who should have been told. Paste an incoming webhook URL from
          Slack's own{' '}
          <a href="https://api.slack.com/messaging/webhooks" target="_blank" rel="noreferrer" className="text-brand underline underline-offset-2">
            Incoming Webhooks
          </a>{' '}
          app settings.
        </p>
      </div>

      {slack ? (
        <div className="flex items-center justify-between gap-3 rounded border border-border bg-secondary px-3 py-2.5">
          <div>
            <p className="text-[13px] font-medium">Connected</p>
            {slack.error_message && <p className="mt-0.5 text-[12px] text-destructive">{slack.error_message}</p>}
          </div>
          <Button type="button" variant="outline" size="sm" disabled={disconnect.isPending} onClick={() => disconnect.mutate(slack.id)}>
            Disconnect
          </Button>
        </div>
      ) : (
        <form
          className="flex flex-wrap items-end gap-2"
          onSubmit={(event) => {
            event.preventDefault()
            connect.mutate()
          }}
        >
          <div className="w-full max-w-sm space-y-1">
            <Label htmlFor="slack-webhook-url">Incoming webhook URL</Label>
            <Input
              id="slack-webhook-url"
              value={webhookUrl}
              onChange={(event) => setWebhookUrl(event.target.value)}
              placeholder="https://hooks.slack.com/services/..."
            />
          </div>
          <Button type="submit" disabled={connect.isPending || webhookUrl.trim() === ''}>
            Connect
          </Button>
        </form>
      )}
      {connect.isError && <p className="text-[12px] text-destructive">{(connect.error as Error).message}</p>}
      {disconnect.isError && <p className="text-[12px] text-destructive">{(disconnect.error as Error).message}</p>}
    </Card>
  )
}
