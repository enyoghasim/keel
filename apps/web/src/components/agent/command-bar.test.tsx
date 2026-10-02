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
  conversation_id: 'c1',
  person_id: 2,
  message: 'Can I expense a €1,200 flight to RubyConf?',
  status: 'pending',
  final_text: null,
  total_tokens: 0,
  error_message: null,
  cost_usd: null,
  feedback: null,
  feedback_reason: null,
  created_at: '2026-10-02T10:00:00Z',
  steps: [],
  proposal_ids: [],
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
      'GET /api/companies/1/agent_runs': envelope([]),
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
      'GET /api/companies/1/agent_runs': envelope([]),
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

  it('links an answer that made a proposal to the proposals page', async () => {
    const user = userEvent.setup()
    const proposed: AgentRun = { ...completed, proposal_ids: [3] }
    mockApi({
      'GET /api/companies/1/session': envelope(ngozi),
      'GET /api/companies/1/agent_runs': envelope([proposed]),
      'GET /api/companies/1/agent_runs?conversation_id=c1': envelope([proposed]),
      'GET /api/companies/1/change_proposals': envelope([]),
    })
    const { router } = await renderApp('/assemble')

    await user.click(screen.getByRole('button', { name: /ask keel or search/i }))
    const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
    await user.click(await within(bar).findByRole('option', { name: proposed.message }))
    const answer = await within(bar).findByRole('region', { name: 'Agent answer' })
    await user.click(within(answer).getByRole('button', { name: 'View proposal' }))

    await waitFor(() => expect(router.state.location.pathname).toBe('/proposals'))
    expect(screen.queryByRole('dialog', { name: 'Ask Keel' })).not.toBeInTheDocument()
  })

  it('shows no proposal link on an answer that made none', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/session': envelope(ngozi),
      'GET /api/companies/1/agent_runs': envelope([completed]),
      'GET /api/companies/1/agent_runs?conversation_id=c1': envelope([completed]),
    })
    await renderApp('/assemble')

    await user.click(screen.getByRole('button', { name: /ask keel or search/i }))
    const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
    await user.click(await within(bar).findByRole('option', { name: completed.message }))
    const answer = await within(bar).findByRole('region', { name: 'Agent answer' })

    expect(within(answer).queryByRole('button', { name: /view proposal/i })).not.toBeInTheDocument()
  })

  it('lets the person rate a finished answer', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      'GET /api/companies/1/session': envelope(ngozi),
      'GET /api/companies/1/agent_runs': envelope([completed]),
      'GET /api/companies/1/agent_runs?conversation_id=c1': envelope([completed]),
      'POST /api/companies/1/agent_runs/5/feedback': envelope({ ...completed, feedback: 'up' }),
    })
    await renderApp('/assemble')

    await user.click(screen.getByRole('button', { name: /ask keel or search/i }))
    const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
    await user.click(await within(bar).findByRole('option', { name: completed.message }))
    const answer = await within(bar).findByRole('region', { name: 'Agent answer' })
    await user.click(within(answer).getByRole('button', { name: 'Good answer' }))

    expect(await within(answer).findByRole('button', { name: 'Good answer', pressed: true })).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/agent_runs/5/feedback', expect.objectContaining({ method: 'POST' }))
  })

  describe('conversations', () => {
    const followUpPending: AgentRun = { ...pending, id: 6, message: 'And what about €2,000?' }
    const followUpDone: AgentRun = { ...followUpPending, status: 'completed', final_text: 'Then Tunde and Ada both approve.' }
    const other: AgentRun = { ...completed, id: 9, conversation_id: 'c2', message: 'Who is my manager?', final_text: 'Tunde Bakare.' }

    it('continues the open conversation with a follow-up, keeping the earlier turn on screen', async () => {
      const user = userEvent.setup()
      const fetchMock = mockApi({
        'GET /api/companies/1/session': envelope(ngozi),
        'GET /api/companies/1/agent_runs': envelope([]),
        'POST /api/companies/1/agent_runs': [
          { status: 202, body: { success: true, message: '', data: { ...completed } } },
          { status: 202, body: { success: true, message: '', data: followUpPending } },
        ],
      })
      await renderApp('/assemble')

      await user.click(screen.getByRole('button', { name: /ask keel or search/i }))
      const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
      await user.type(within(bar).getByRole('combobox'), 'Can I expense a €1,200 flight to RubyConf?{Enter}')
      await within(bar).findByText('Yes, but Tunde Bakare has to approve it first.')

      await user.type(within(bar).getByRole('textbox', { name: 'Ask a follow-up' }), 'And what about €2,000?{Enter}')

      await waitFor(() =>
        expect(fetchMock).toHaveBeenCalledWith(
          '/api/companies/1/agent_runs',
          expect.objectContaining({ method: 'POST', body: JSON.stringify({ message: 'And what about €2,000?', conversation_id: 'c1' }) }),
        ),
      )
      expect(await within(bar).findAllByRole('region', { name: 'Agent answer' })).toHaveLength(2)
      expect(within(bar).getByText('Yes, but Tunde Bakare has to approve it first.')).toBeInTheDocument()
      // The follow-up waits for the answer in flight before another can be sent.
      expect(within(bar).getByRole('textbox', { name: 'Ask a follow-up' })).toBeDisabled()
      act(() => agentSubscription()[1].received({ event: 'run', run: followUpDone }))
      expect(await within(bar).findByText('Then Tunde and Ada both approve.')).toBeInTheDocument()
      expect(within(bar).getByRole('textbox', { name: 'Ask a follow-up' })).toBeEnabled()
    })

    it('lists recent conversations, newest first, and reopens one with its whole thread', async () => {
      const user = userEvent.setup()
      mockApi({
        'GET /api/companies/1/session': envelope(ngozi),
        // Newest first: the follow-up and its earlier turn share a conversation.
        'GET /api/companies/1/agent_runs': envelope([other, followUpDone, completed]),
        'GET /api/companies/1/agent_runs?conversation_id=c1': envelope([followUpDone, completed]),
      })
      await renderApp('/assemble')

      await user.keyboard('{Meta>}k{/Meta}')
      const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
      const recent = await within(bar).findAllByRole('option', { name: /\?$/ })
      expect(recent.map((o) => o.textContent)).toEqual(['Who is my manager?', 'And what about €2,000?'])

      await user.click(recent[1])

      const turns = await within(bar).findAllByRole('region', { name: 'Agent answer' })
      expect(turns.map((t) => within(t).getByText(/\?$/).textContent)).toEqual([completed.message, followUpDone.message])
      expect(localStorage.getItem('keel-agent-conversation:1')).toBe('c1')
    })

    it('brings the last conversation back after a page refresh, even mid-run', async () => {
      const user = userEvent.setup()
      localStorage.setItem('keel-agent-conversation:1', 'c1')
      mockApi({
        'GET /api/companies/1/session': envelope(ngozi),
        'GET /api/companies/1/agent_runs?conversation_id=c1': envelope([pending]),
      })
      await renderApp('/assemble')

      // The trace button is live before the bar is ever opened.
      await waitFor(() => expect(screen.getByRole('button', { name: 'Agent trace' })).toBeEnabled())
      await user.keyboard('{Meta>}k{/Meta}')
      const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
      expect(await within(bar).findByText('Thinking…')).toBeInTheDocument()

      act(() => agentSubscription()[1].received({ event: 'run', run: completed }))
      expect(await within(bar).findByText('Yes, but Tunde Bakare has to approve it first.')).toBeInTheDocument()
    })

    it('starts a new conversation from "New conversation", forgetting the open one', async () => {
      const user = userEvent.setup()
      localStorage.setItem('keel-agent-conversation:1', 'c1')
      mockApi({
        'GET /api/companies/1/session': envelope(ngozi),
        'GET /api/companies/1/agent_runs': envelope([completed]),
        'GET /api/companies/1/agent_runs?conversation_id=c1': envelope([completed]),
      })
      await renderApp('/assemble')

      await user.keyboard('{Meta>}k{/Meta}')
      const bar = await screen.findByRole('dialog', { name: 'Ask Keel' })
      await user.click(await within(bar).findByRole('button', { name: 'New conversation' }))

      expect(await within(bar).findByRole('combobox')).toBeInTheDocument()
      expect(localStorage.getItem('keel-agent-conversation:1')).toBeNull()
      expect(within(bar).getByRole('option', { name: completed.message })).toBeInTheDocument()
    })
  })
})
