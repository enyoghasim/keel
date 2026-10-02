import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { act, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { McpCall } from 'api-types'
import { describe, expect, it, vi } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { McpCallsPanel } from './mcp-calls-panel'

const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))

const call: McpCall = {
  id: 1,
  tool_name: 'who_approves',
  input: { request_kind: 'leave', payload: { days: 5 } },
  output: { steps: [{ person: { name: 'Tunde Bakare' } }] },
  is_error: false,
  latency_ms: 18,
  token_name: 'Claude Desktop',
  created_at: '2026-10-02T10:00:00Z',
}
const path = 'GET /api/companies/1/mcp_calls'
const list = (calls: McpCall[]) => ({ [path]: { body: { success: true, message: '', data: calls } } })

// A distinct person per test: Action Cable subscriptions are shared per
// channel and params, so a reused id would skip the mocked create.
let nextPersonId = 7
function renderPanel() {
  const personId = nextPersonId++
  const rendered = render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <McpCallsPanel companyId="1" personId={personId} />
    </QueryClientProvider>,
  )
  return { ...rendered, personId }
}

describe('McpCallsPanel', () => {
  it('says so when no MCP client has called yet', async () => {
    mockApi(list([]))
    renderPanel()

    expect(await screen.findByText(/no calls yet/i)).toBeInTheDocument()
  })

  it('lists each call with its tool, the token it used and its latency, flagging errors', async () => {
    mockApi(list([call, { ...call, id: 2, tool_name: 'org_lookup', is_error: true, latency_ms: 3 }]))
    renderPanel()

    const first = await screen.findByRole('button', { name: /who_approves/ })
    expect(first).toHaveTextContent('Claude Desktop')
    expect(first).toHaveTextContent('18 ms')
    expect(screen.getByRole('button', { name: /org_lookup/ })).toHaveTextContent('Error')
  })

  it('opens a call in the trace drawer with its input and output', async () => {
    const user = userEvent.setup()
    mockApi(list([call]))
    renderPanel()

    await user.click(await screen.findByRole('button', { name: /who_approves/ }))

    const drawer = screen.getByRole('dialog', { name: 'MCP call' })
    expect(within(drawer).getByText('who_approves')).toBeInTheDocument()
    await user.click(within(drawer).getByText('Input'))
    expect(within(drawer).getByText(/"days": 5/)).toBeVisible()
    await user.click(within(drawer).getByText('Output'))
    expect(within(drawer).getByText(/Tunde Bakare/)).toBeVisible()
  })

  it('shows a call the moment it arrives over the cable, without a reload', async () => {
    mockApi({ [path]: [{ body: { success: true, message: '', data: [] } }, { body: { success: true, message: '', data: [call] } }] })
    const { personId } = renderPanel()
    await screen.findByText(/no calls yet/i)

    expect(subscriptionsCreate.mock.calls.at(-1)?.[0]).toMatchObject({ channel: 'McpCallChannel', person_id: personId })
    act(() => subscriptionsCreate.mock.calls.at(-1)?.[1].received(call))

    expect(await screen.findByRole('button', { name: /who_approves/ })).toBeInTheDocument()
  })
})
