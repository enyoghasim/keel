import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { PolicyWithRules, Rule, RuleConflict, RuleResolution } from 'api-types'
import { describe, expect, it, vi } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { PolicyDetail } from './policy-detail'

// One cable test for this file: subscriptions are shared per channel+params for
// the life of a test module (see src/lib/cable.ts), so the answer flow is the
// only example here that drives the channel.
const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_params: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))

const ok = (data: unknown) => ({ body: { success: true, message: '', data } })

const conference: Rule = {
  id: 1,
  key: 'expense_conference',
  conditions: { field: 'payload.amount_eur', op: 'lte', value: 1000 },
  actions: { decision: 'auto_approve' },
  priority: 3,
  source_quote: 'Engineers attending conferences are automatically approved up to EUR 1,000.',
  ambiguities: [{ phrase: 'up to', question: 'Does the limit include travel?', options: ['Ticket only', 'Everything'] }],
  status: 'extracted',
  policy_id: 5,
}

const draft = (rules: Rule[]): PolicyWithRules => ({
  id: 5,
  title: 'Expense Policy',
  category: 'expense',
  status: 'draft',
  version: 1,
  created_at: '2026-01-01T00:00:00Z',
  rules,
})

function renderDetail() {
  return render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <PolicyDetail companyId="1" policyId={5} />
    </QueryClientProvider>,
  )
}

describe('a draft policy', () => {
  it('cannot be published while a rule has an open question', async () => {
    mockApi({
      'GET /api/companies/1/policies/5': ok(draft([conference])),
      'GET /api/companies/1/policies/5/conflicts': ok([]),
    })

    renderDetail()

    expect(await screen.findByRole('button', { name: 'Publish' })).toBeDisabled()
    expect(screen.getByText('Answer the open question before publishing.')).toBeInTheDocument()
  })

  it('is published once nothing is open, and says it is active as the next version', async () => {
    const user = userEvent.setup()
    const resolved: Rule = { ...conference, ambiguities: [], status: 'resolved' }
    const fetchMock = mockApi({
      'GET /api/companies/1/policies/5': [ok(draft([resolved])), ok({ ...draft([{ ...resolved, status: 'active' }]), status: 'active', version: 2 })],
      'GET /api/companies/1/policies/5/conflicts': ok([]),
      'GET /api/companies/1/policies': ok([]),
      'POST /api/companies/1/policies/5/publish': ok({}),
    })

    renderDetail()
    await user.click(await screen.findByRole('button', { name: 'Publish' }))

    expect(await screen.findByText('Active · v2')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/policies/5/publish', expect.objectContaining({ method: 'POST' }))
  })

  it('lists a conflict and applies the suggested fix', async () => {
    const user = userEvent.setup()
    const conflict: RuleConflict = {
      rule_a_key: 'travel_under_800',
      rule_b_key: 'expense_over_500',
      example: { 'payload.amount_eur': 650 },
      explanation: 'Rules travel_under_800 (auto approved) and expense_over_500 (sent for approval) both match requests like amount eur 650.',
      fix: { rule_key: 'travel_under_800', new_priority: 2 },
    }
    const fetchMock = mockApi({
      'GET /api/companies/1/policies/5': ok(draft([{ ...conference, ambiguities: [], status: 'resolved' }])),
      'GET /api/companies/1/policies/5/conflicts': [ok([conflict]), ok([])],
      'POST /api/companies/1/policies/5/conflict_fixes': ok([]),
    })

    renderDetail()
    expect(await screen.findByText(/Rules travel_under_800 \(auto approved\)/)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Accept suggested fix' }))

    await waitFor(() => expect(screen.queryByText(/Rules travel_under_800/)).not.toBeInTheDocument())
    const post = fetchMock.mock.calls.find(([url]) => url === '/api/companies/1/policies/5/conflict_fixes')!
    expect(JSON.parse(post[1]!.body as string)).toEqual({ rule_key: 'travel_under_800' })
  })

  it('applies an answer as a new rule version and shows the before and after', async () => {
    const user = userEvent.setup()
    const after: Rule = {
      ...conference,
      id: 9,
      ambiguities: [],
      status: 'resolved',
      conditions: {
        all: [
          { field: 'payload.amount_eur', op: 'lte', value: 1000 },
          { field: 'payload.category', op: 'eq', value: 'conference_ticket' },
        ],
      },
    }
    const pending: RuleResolution = {
      id: 3,
      rule_id: 1,
      new_rule_id: null,
      ambiguity_index: 0,
      answer: 'Ticket only',
      status: 'pending',
      error_message: null,
      created_at: '2026-01-01T00:00:00Z',
      before: conference,
      after: null,
    }
    const fetchMock = mockApi({
      'GET /api/companies/1/policies/5': [ok(draft([conference])), ok(draft([after]))],
      'GET /api/companies/1/policies/5/conflicts': ok([]),
      'POST /api/companies/1/policies/5/rule_resolutions': { status: 202, body: { success: true, message: '', data: pending } },
    })

    renderDetail()
    await user.click(await screen.findByRole('button', { name: 'Ticket only' }))

    expect(await screen.findByText(/Updating the rule for “Ticket only”/)).toBeInTheDocument()
    const post = fetchMock.mock.calls.find(([url]) => url === '/api/companies/1/policies/5/rule_resolutions')!
    expect(JSON.parse(post[1]!.body as string)).toEqual({ rule_id: 1, ambiguity_index: 0, answer: 'Ticket only' })
    expect(subscriptionsCreate).toHaveBeenCalledWith(
      { channel: 'RuleResolutionChannel', rule_resolution_id: 3 },
      expect.objectContaining({ received: expect.any(Function) }),
    )

    const mixin = subscriptionsCreate.mock.calls[0][1]
    mixin.received({ ...pending, status: 'resolved', new_rule_id: 9, after })

    expect(await screen.findByText('Rule expense_conference updated for “Ticket only”')).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByText('Does the limit include travel?')).not.toBeInTheDocument())
    expect(screen.getByRole('button', { name: 'Publish' })).toBeEnabled()
  })
})
