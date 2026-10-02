import { act, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Insight, Person } from 'api-types'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { setCurrentCompanyId } from '../lib/current-company'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

// Same stable-spy setup as assemble.test.tsx: cable.ts's consumer is a
// module-level singleton, so the subscriptions.create spy is hoisted.
const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))

const currentPerson: Person = {
  id: 1,
  name: 'Ada Nwosu',
  email: 'ada@nubo.test',
  title: 'HR Admin',
  department_id: null,
  manager_id: null,
  location: null,
  start_date: null,
  roles: ['hr_admin'],
}
const sessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: currentPerson } } }

const pending: Insight = {
  id: 9,
  person_id: 1,
  question: 'Leave days by department last quarter',
  status: 'pending',
  query: null,
  clarification: null,
  result: null,
  error_message: null,
  created_at: '2026-10-02T10:00:00Z',
}

const answered: Insight = {
  ...pending,
  status: 'answered',
  query: {
    metric: 'leave_days',
    group_by: 'department',
    chart: 'bar',
    time_range: { from: '2026-07-01', to: '2026-09-30' },
  },
  result: {
    rows: [
      { key: 2, label: 'Sales', value: 8 },
      { key: 1, label: 'Engineering', value: 2 },
    ],
    unit: 'days',
    summary: 'Sales is highest with 8 days, out of 2 departments.',
  },
}

function envelope<T>(data: T) {
  return { body: { success: true, message: '', data } }
}

function lastSubscription() {
  return subscriptionsCreate.mock.calls[subscriptionsCreate.mock.calls.length - 1]
}

describe('/insights', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when no company has been selected yet', async () => {
    await renderApp('/insights')

    expect(await screen.findByRole('heading', { name: 'Insights' })).toBeInTheDocument()
    expect(screen.getByText(/assemble one on the assemble page first/i)).toBeInTheDocument()
  })

  it('offers four suggested questions so the page never starts blank', async () => {
    setCurrentCompanyId('1')
    mockApi({ ...sessionRoute, 'GET /api/companies/1/insights': envelope([]) })

    await renderApp('/insights')

    expect(await screen.findByRole('button', { name: 'Who is overloaded with approvals this month?' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Leave days by department last quarter' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'How often do managers override the expense policy?' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Median time to approve an expense by department' })).toBeInTheDocument()
    expect(screen.getByText('None yet.')).toBeInTheDocument()
  })

  it('asks a suggested question, then shows how it was understood and the answer once InsightChannel reports back', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const fetchMock = mockApi({
      ...sessionRoute,
      'GET /api/companies/1/insights': [envelope([]), envelope([answered])],
      'POST /api/companies/1/insights': { status: 202, body: { success: true, message: 'Working on it.', data: pending } },
      'GET /api/companies/1/insights/9': envelope(pending),
    })

    await renderApp('/insights')
    await user.click(await screen.findByRole('button', { name: 'Leave days by department last quarter' }))

    const answer = await screen.findByRole('region', { name: 'Answer' })
    expect(within(answer).getByRole('heading', { name: 'Leave days by department last quarter' })).toBeInTheDocument()
    expect(within(answer).getByText('Working out how to answer that…')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/insights',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ question: 'Leave days by department last quarter' }) }),
    )
    expect(lastSubscription()[0]).toEqual({ channel: 'InsightChannel', insight_query_id: 9 })

    act(() => lastSubscription()[1].received(answered))

    expect(await within(answer).findByText('Sales is highest with 8 days, out of 2 departments.')).toBeInTheDocument()
    const chips = within(within(answer).getByRole('list', { name: 'How Keel understood the question' })).getAllByRole('listitem')
    expect(chips.map((chip) => chip.textContent)).toEqual(['Leave days', 'Jul–Sep 2026', 'by department'])
    expect(within(answer).getByRole('cell', { name: '8 days' })).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: 'Leave days by department last quarter', current: true })).toBeInTheDocument()
  })

  it('asks a typed question and shows a clarifying question back instead of an answer', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const clarifying: Insight = { ...pending, question: 'Leave last quarter?', status: 'needs_clarification', clarification: 'Calendar Q3 or fiscal?' }
    mockApi({
      ...sessionRoute,
      'GET /api/companies/1/insights': envelope([]),
      'POST /api/companies/1/insights': { status: 202, body: { success: true, message: '', data: { ...pending, question: 'Leave last quarter?' } } },
      'GET /api/companies/1/insights/9': envelope(clarifying),
    })

    await renderApp('/insights')
    await user.type(await screen.findByLabelText('Ask a question'), 'Leave last quarter?')
    await user.click(screen.getByRole('button', { name: 'Ask' }))
    await screen.findByRole('region', { name: 'Answer' })
    act(() => lastSubscription()[1].received(clarifying))

    expect(await screen.findByText('Calendar Q3 or fiscal?')).toBeInTheDocument()
    expect(screen.getByText('Keel needs a bit more detail')).toBeInTheDocument()
  })

  it('reopens a recent question, showing the friendly reason it could not be answered', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const failed: Insight = {
      ...pending,
      id: 4,
      question: 'Leave by approver',
      status: 'failed',
      query: { metric: 'leave_days', group_by: 'approver', chart: 'bar' },
      error_message: "Leave days can't be grouped by approver. Try: department, person, month.",
    }
    mockApi({
      ...sessionRoute,
      'GET /api/companies/1/insights': envelope([failed]),
      'GET /api/companies/1/insights/4': envelope(failed),
    })

    await renderApp('/insights')
    await user.click(await screen.findByRole('button', { name: 'Leave by approver' }))

    expect(await screen.findByText("Leave days can't be grouped by approver. Try: department, person, month.")).toBeInTheDocument()
    // The query object is kept even on failure, so the chips still show what was asked for.
    const chips = within(screen.getByRole('list', { name: 'How Keel understood the question' })).getAllByRole('listitem')
    expect(chips.map((chip) => chip.textContent)).toEqual(['Leave days', 'by approver'])
  })
})
