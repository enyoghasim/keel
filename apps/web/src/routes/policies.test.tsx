import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Person, Policy, PolicyWithRules } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { setCurrentCompanyId } from '../lib/current-company'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

const expensePolicy: Policy = {
  id: 5,
  title: 'Expense Policy',
  category: 'expense',
  status: 'active',
  version: 1,
  created_at: '2026-01-01T00:00:00Z',
}

const leavePolicy: Policy = {
  id: 6,
  title: 'Leave Policy',
  category: 'leave',
  status: 'draft',
  version: 1,
  created_at: '2026-01-02T00:00:00Z',
}

const expensePolicyWithRules: PolicyWithRules = {
  ...expensePolicy,
  rules: [
    {
      id: 1,
      key: 'expense_conference_engineering',
      conditions: {
        all: [
          { field: 'requester.department', op: 'eq', value: 'Engineering' },
          { field: 'payload.amount_eur', op: 'lte', value: 1000 },
        ],
      },
      actions: { decision: 'auto_approve' },
      priority: 10,
      source_quote: 'Engineers may expense conferences up to €1,000.',
      ambiguities: [],
      status: 'active',
      policy_id: 5,
    },
  ],
}

const leavePolicyWithRules: PolicyWithRules = {
  ...leavePolicy,
  rules: [
    {
      id: 2,
      key: 'leave_notice_period',
      conditions: { field: 'payload.notice_days', op: 'lt', value: 14 },
      actions: { decision: 'reject', reason: 'insufficient notice' },
      priority: 10,
      source_quote: 'Leave requests need 14 days notice.',
      ambiguities: [{ phrase: '14 days', question: 'Does notice include weekends?', options: ['Yes', 'No'] }],
      status: 'extracted',
      policy_id: 6,
    },
  ],
}

const people: Person[] = []
const peopleRoute = { 'GET /api/companies/1/people': { body: { success: true, message: '', data: people } } }

describe('/policies', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when no company has been selected yet', async () => {
    await renderApp('/policies')

    expect(await screen.findByRole('heading', { name: 'Policies' })).toBeInTheDocument()
    expect(screen.getByText(/assemble one on the assemble page first/i)).toBeInTheDocument()
  })

  it('shows an empty state when the company has no policies', async () => {
    setCurrentCompanyId('1')
    mockApi({ 'GET /api/companies/1/policies': { body: { success: true, message: '', data: [] } } })

    await renderApp('/policies')

    expect(await screen.findByText(/no policies yet/i)).toBeInTheDocument()
  })

  it('shows the first policy selected, with its handbook quotes and rule cards', async () => {
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/policies': { body: { success: true, message: '', data: [expensePolicy, leavePolicy] } },
      'GET /api/companies/1/policies/5': { body: { success: true, message: '', data: expensePolicyWithRules } },
      ...peopleRoute,
    })

    await renderApp('/policies')

    expect(await screen.findByRole('tab', { name: /Expense Policy/ })).toHaveAttribute('aria-selected', 'true')
    expect(await screen.findByText(/Engineers may expense conferences up to €1,000\./)).toBeInTheDocument()
    expect(
      screen.getByText('If department is Engineering and amount ≤ €1,000 → auto-approve'),
    ).toBeInTheDocument()
  })

  it('switches policies and shows an ambiguity banner for an open ambiguity', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/policies': { body: { success: true, message: '', data: [expensePolicy, leavePolicy] } },
      'GET /api/companies/1/policies/5': { body: { success: true, message: '', data: expensePolicyWithRules } },
      'GET /api/companies/1/policies/6': { body: { success: true, message: '', data: leavePolicyWithRules } },
      ...peopleRoute,
    })

    await renderApp('/policies')
    await screen.findByText(/Engineers may expense conferences up to €1,000\./)

    await user.click(screen.getByRole('tab', { name: /Leave Policy/ }))

    expect(await screen.findByText('Does notice include weekends?')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Yes' })).toBeInTheDocument()
  })
})
