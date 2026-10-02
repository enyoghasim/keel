import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Person, PolicyWithRules } from 'api-types'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { PolicyDetail } from './policy-detail'

const policy: PolicyWithRules = {
  id: 5,
  title: 'Expense Policy',
  category: 'expense',
  status: 'active',
  version: 1,
  created_at: '2026-01-01T00:00:00Z',
  rules: [
    {
      id: 1,
      key: 'expense_conference_engineering',
      conditions: { field: 'payload.amount_eur', op: 'lte', value: 1000 },
      actions: { decision: 'auto_approve' },
      priority: 10,
      source_quote: 'Engineers may expense conferences up to €1,000.',
      ambiguities: [],
      status: 'active',
      policy_id: 5,
    },
    {
      id: 2,
      key: 'expense_large',
      conditions: { field: 'payload.amount_eur', op: 'gt', value: 2000 },
      actions: { decision: 'require_approval', approvers: ['manager_of(requester)'] },
      priority: 8,
      source_quote: 'Expenses over €2,000 need manager approval.',
      ambiguities: [{ phrase: 'approval', question: 'Who approves international travel?', options: ['Manager', 'Finance lead'] }],
      status: 'extracted',
      policy_id: 5,
    },
  ],
}

const people: Person[] = [
  {
    id: 1,
    name: 'Ngozi Doe',
    email: 'ngozi@nubo.test',
    title: 'Engineer',
    department_id: 10,
    manager_id: null,
    location: null,
    start_date: null,
    roles: [],
  },
]

function renderDetail() {
  return render(
    <QueryClientProvider client={new QueryClient()}>
      <PolicyDetail companyId="1" policyId={5} />
    </QueryClientProvider>,
  )
}

describe('PolicyDetail', () => {
  it('shows the handbook quotes and rule cards for the selected policy', async () => {
    mockApi({
      'GET /api/companies/1/policies/5': { body: { success: true, message: '', data: policy } },
      'GET /api/companies/1/people': { body: { success: true, message: '', data: people } },
    })

    renderDetail()

    expect(await screen.findByText(/Engineers may expense conferences up to €1,000\./)).toBeInTheDocument()
    expect(
      screen.getByText('If amount ≤ €1,000 → auto-approve'),
    ).toBeInTheDocument()
    expect(screen.getByText('Who approves international travel?')).toBeInTheDocument()
  })

  it('highlights a rule card and its source quote together on hover', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/policies/5': { body: { success: true, message: '', data: policy } },
      'GET /api/companies/1/people': { body: { success: true, message: '', data: people } },
    })

    renderDetail()
    await screen.findByText(/Engineers may expense conferences up to €1,000\./)

    await user.hover(screen.getByText('If amount ≤ €1,000 → auto-approve'))

    expect(screen.getByTestId('source-quote-1').className).toContain('border-brand')
  })

  it('highlights the matched rule card after running the tester', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/policies/5': { body: { success: true, message: '', data: policy } },
      'GET /api/companies/1/people': { body: { success: true, message: '', data: people } },
      'POST /api/companies/1/policies/5/test': {
        body: {
          success: true,
          message: '',
          data: { outcome: 'auto_approve', matched_rule_keys: ['expense_conference_engineering'], approvers: [], errors: [], explanation: null },
        },
      },
    })

    renderDetail()
    await screen.findByText(/Engineers may expense conferences up to €1,000\./)
    await screen.findByRole('option', { name: 'Ngozi Doe' })

    await user.selectOptions(screen.getByLabelText('Requester'), '1')
    await user.click(screen.getByRole('button', { name: 'Run test' }))
    await screen.findByText('Auto approve')

    const matchedCard = screen.getByText('If amount ≤ €1,000 → auto-approve').closest('div')?.parentElement
    expect(matchedCard?.className).toContain('border-info')
  })
})
