import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { CreatedPersonalAccessToken, Envelope, PersonalAccessToken } from 'api-types'
import { useState } from 'react'
import { api } from '../../lib/api'
import { formatRunDate } from '../trust/format'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const tokensKey = (companyId: string) => ['personal_access_tokens', companyId] as const

/**
 * Personal access tokens for Keel's MCP server (SPEC.md section 13): a
 * person creates one, copies it once, and gives it to an MCP client such as
 * Claude Desktop, which then acts as them. Only the token's digest is
 * stored, so the value is shown at creation and never again.
 */
export function TokensPanel({ companyId }: { companyId: string }) {
  const queryClient = useQueryClient()
  const [name, setName] = useState('')
  const [created, setCreated] = useState<CreatedPersonalAccessToken | null>(null)

  const query = useQuery({
    queryKey: tokensKey(companyId),
    queryFn: () => api.get<Envelope<PersonalAccessToken[]>>(`/companies/${companyId}/personal_access_tokens`),
  })

  const create = useMutation({
    mutationFn: () => api.post<Envelope<CreatedPersonalAccessToken>>(`/companies/${companyId}/personal_access_tokens`, { name }),
    onSuccess: (response) => {
      setCreated(response.data ?? null)
      setName('')
      queryClient.invalidateQueries({ queryKey: tokensKey(companyId) })
    },
  })

  const revoke = useMutation({
    mutationFn: (id: number) => api.delete<Envelope<null>>(`/companies/${companyId}/personal_access_tokens/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: tokensKey(companyId) }),
  })

  const tokens = query.data?.data ?? []
  const origin = typeof window === 'undefined' ? '' : window.location.origin

  return (
    <Card role="region" aria-label="Personal access tokens">
      <div>
        <h2 className="text-[15px] font-semibold">Personal access tokens</h2>
        <p className="mt-1 text-[13px] text-muted-foreground">
          Let an MCP client such as Claude Desktop ask Keel who approves your leave, check a policy or file a leave request as you. A token
          acts with your permissions — keep it secret and revoke it if it leaks.
        </p>
      </div>

      {created && (
        <div role="alert" className="space-y-2 rounded border border-success/30 bg-success-muted px-3 py-2.5 text-[13px]">
          <p>
            Token <strong>{created.name}</strong> created. Copy it now — it won't be shown again.
          </p>
          <code className="block overflow-x-auto rounded bg-card px-2 py-1.5 font-mono text-[12px]">{created.token}</code>
          <p className="text-muted-foreground">Connect Claude Desktop (or any MCP client) to this server:</p>
          <pre className="overflow-x-auto rounded bg-card px-2 py-1.5 font-mono text-[11.5px]">{`URL: ${origin}/mcp\nAuthorization: Bearer ${created.token}`}</pre>
        </div>
      )}

      <form
        className="flex flex-wrap items-end gap-2"
        onSubmit={(event) => {
          event.preventDefault()
          create.mutate()
        }}
      >
        <div className="w-full max-w-xs space-y-1">
          <Label htmlFor="token-name">Token name</Label>
          <Input id="token-name" value={name} onChange={(event) => setName(event.target.value)} placeholder="e.g. Claude Desktop" />
        </div>
        <Button type="submit" disabled={create.isPending}>
          Create token
        </Button>
      </form>
      {create.isError && <p className="text-[12px] text-destructive">{(create.error as Error).message}</p>}

      {query.isError && <p className="text-[13px] text-destructive">{(query.error as Error).message}</p>}
      {query.isSuccess && tokens.length === 0 && <p className="text-[13px] text-muted-foreground">No tokens yet.</p>}
      {tokens.length > 0 && (
        <ul className="divide-y divide-border">
          {tokens.map((token) => (
            <li key={token.id} aria-label={token.name} className="flex items-center justify-between gap-3 py-2.5">
              <div className="min-w-0">
                <p className="truncate text-[13px] font-medium">{token.name}</p>
                <p className="text-[12px] text-muted-foreground">
                  Created {formatRunDate(token.created_at)} · {token.last_used_at ? `Last used ${formatRunDate(token.last_used_at)}` : 'Never used'}
                </p>
              </div>
              <Button
                type="button"
                variant="outline"
                size="sm"
                aria-label={`Revoke ${token.name}`}
                onClick={() => revoke.mutate(token.id)}
                disabled={revoke.isPending}
              >
                Revoke
              </Button>
            </li>
          ))}
        </ul>
      )}
      {revoke.isError && <p className="text-[12px] text-destructive">{(revoke.error as Error).message}</p>}
    </Card>
  )
}
