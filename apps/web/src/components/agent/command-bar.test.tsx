import { act, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { AgentRun, Person } from 'api-types'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { setCurrentCompanyId } from '../../lib/current-company'
import { mockApi } from '../../test/mock-api'
import { renderApp } from '../../test/render-app'

// Same stable-spy setup as the route tests that use Action Cable.
const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))

const ngozi: Person = {
  id: 2,
  name: 'Ngozi Okafor',
  email: 'ngozi@nubo.test',
  title: 'Account Executive',
  department_id: null,
  manager_id: 1,
  location: null,
  start_date: null,
  roles: [],
}

const pending: AgentRun = {
  id: 5,
  person_id: 2,
  message: 'Can I expense a €1,200 flight to RubyConf?',
  status: 'pending',
  final_text: null,
  total_tokens: 0,
  error_message: null,
  created_at: '2026-10-02T10:00:00Z',
  steps: [],
}

const toolStep = {
  id: 52,
  position: 2,
  kind: 'tool' as const,
  tool_name: 'check_policy',
  input: { request_kind: 'expense', payload: { amount_eur: 1200 } },
  output: { decision: 'require_approval' },
  latency_ms: 14,
  tokens: null,
}

const completed: AgentRun = {
  ...pending,
  status: 'completed',
  final_text: 'Yes, but Tunde Bakare has to approve it first.',
  steps: [toolStep],
}

function envelope<T>(data: T) {
  return { body: { success: true, message: '', data } }
}

const agentSubscription = () =>
  subscriptionsCreate.mock.calls.filter(([params]) => (params as { channel: string }).channel === 'AgentChannel').at(-1)!

describe('CommandBar', () => {
  beforeEach(() => {
    localStorage.clear()
    setCurrentCompanyId('1')
  })

  it('opens with ⌘K and jumps to a page', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/session': envelope(ngozi),
      'GET /api/companies/1/insights': envelope([]),
    })
    const { router } = await renderApp('/assemble')

    await user.keyboard('{Meta>}k{/Meta}')
    const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
    await user.type(within(bar).getByRole('combobox'), 'insights')
    await user.click(within(bar).getByRole('option', { name: 'Insights' }))

    await waitFor(() => expect(router.state.location.pathname).toBe('/insights'))
    expect(screen.queryByRole('dialog', { name: 'Ask Keel' })).not.toBeInTheDocument()
  })

  it('sends a question to the agent, fills the answer in live, and opens the trace', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      'GET /api/companies/1/session': envelope(ngozi),
      'POST /api/companies/1/agent_runs': { status: 202, body: { success: true, message: '', data: pending } },
      // The trace drawer refetches on mount, by which time the run has finished.
      'GET /api/companies/1/agent_runs/5': [envelope(pending), envelope(completed)],
    })
    await renderApp('/assemble')

    await user.click(screen.getByRole('button', { name: /ask keel or search/i }))
    const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
    await user.type(within(bar).getByRole('combobox'), 'Can I expense a €1,200 flight to RubyConf?{Enter}')

    const answer = await within(bar).findByRole('region', { name: 'Agent answer' })
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/agent_runs',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ message: 'Can I expense a €1,200 flight to RubyConf?' }) }),
    )
    expect(within(answer).getByText('Thinking…')).toBeInTheDocument()
    expect(agentSubscription()[0]).toEqual({ channel: 'AgentChannel', agent_run_id: 5 })

    act(() => agentSubscription()[1].received({ event: 'step', step: toolStep }))
    expect(await within(answer).findByText('Working… used check_policy')).toBeInTheDocument()

    act(() =>
      agentSubscription()[1].received({
        event: 'run',
        run: completed,
      }),
    )
    expect(await within(answer).findByText('Yes, but Tunde Bakare has to approve it first.')).toBeInTheDocument()

    await user.click(within(answer).getByRole('button', { name: 'Show trace (1 step)' }))
    const trace = await screen.findByRole('dialog', { name: 'Agent trace' })
    expect(within(trace).getByText('check_policy')).toBeInTheDocument()
  })
})
