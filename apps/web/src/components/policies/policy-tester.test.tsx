import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import type { Person } from 'api-types'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { PolicyTester } from './policy-tester'
import { chooseOption } from '../../test/choose-option'

const people: Person[] = [
  {
    id: 1,
    name: 'Ngozi Doe',
    email: 'ngozi@factorial.test',
    title: 'Engineer',
    department_id: 10,
    manager_id: null,
    location: null,
    start_date: null,
    roles: [],
  },
]

function renderTester(onResult: (result: unknown) => void = () => {}) {
  return render(
    <QueryClientProvider client={new QueryClient()}>
      <PolicyTester companyId="1" policyId={5} onResult={onResult} />
    </QueryClientProvider>,
  )
}

describe('PolicyTester', () => {
  it('lets the user pick a requester and amount, then shows the outcome and explanation', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/people': { body: { success: true, message: '', data: people } },
      'POST /api/companies/1/policies/5/test': {
        body: {
          success: true,
          message: '',
          data: {
            outcome: 'auto_approve',
            matched_rule_keys: ['expense_conference_engineering'],
            approvers: [],
            errors: [],
            explanation: "Auto approved — matched rule 'expense_conference_engineering'.",
          },
        },
      },
    })

    renderTester()

    await chooseOption(user, screen.getByLabelText('Requester'), 'Ngozi Doe')
    await user.type(screen.getByLabelText('Amount (EUR)'), '900')
    await user.type(screen.getByLabelText('Category'), 'conference')
    await user.click(screen.getByRole('button', { name: 'Run test' }))

    expect(await screen.findByText(/Auto approved/)).toBeInTheDocument()
    expect(screen.getByText('Auto approve')).toBeInTheDocument()
  })

  it('reports the matched rule keys up via onResult so matched rule cards can be highlighted', async () => {
    const user = userEvent.setup()
    let lastResult: unknown
    mockApi({
      'GET /api/companies/1/people': { body: { success: true, message: '', data: people } },
      'POST /api/companies/1/policies/5/test': {
        body: {
          success: true,
          message: '',
          data: { outcome: 'auto_approve', matched_rule_keys: ['small_expense'], approvers: [], errors: [], explanation: null },
        },
      },
    })

    renderTester((result) => (lastResult = result))

    await chooseOption(user, screen.getByLabelText('Requester'), 'Ngozi Doe')
    await user.click(screen.getByRole('button', { name: 'Run test' }))

    await screen.findByText('Auto approve')
    expect(lastResult).toEqual(
      expect.objectContaining({ matched_rule_keys: ['small_expense'] }),
    )
  })

  it('shows errors returned by the engine, such as a blocked self-approval', async () => {
    const user = userEvent.setup()
    mockApi({
      'GET /api/companies/1/people': { body: { success: true, message: '', data: people } },
      'POST /api/companies/1/policies/5/test': {
        body: {
          success: true,
          message: '',
          data: { outcome: 'blocked', matched_rule_keys: [], approvers: [1], errors: ['self-approval'], explanation: null },
        },
      },
    })

    renderTester()

    await chooseOption(user, screen.getByLabelText('Requester'), 'Ngozi Doe')
    await user.click(screen.getByRole('button', { name: 'Run test' }))

    expect(await screen.findByText('self-approval')).toBeInTheDocument()
    expect(screen.getByText('Blocked')).toBeInTheDocument()
  })
})
