import { render, screen, within } from '@testing-library/react'
import type { Person, RuleChangeProposal } from 'api-types'
import { describe, expect, it } from 'vitest'
import { RuleProposalDetails } from './rule-proposal-details'

const quote = 'Expenses up to €500 are auto-approved.'
const proposal: RuleChangeProposal = {
  id: 7,
  company_id: 1,
  kind: 'rule',
  title: 'Expense Policy: Raise the limit to €800',
  proposed_by: 'agent',
  agent_run_id: 12,
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  created_at: '2026-10-02T00:00:00Z',
  diff: {
    policy_id: 3,
    instruction: 'Raise the limit to €800',
    before: [
      {
        key: 'expense_small_auto',
        priority: 10,
        conditions: { field: 'payload.amount_eur', op: 'lte', value: 500 },
        actions: { decision: 'auto_approve' },
        source_quote: quote,
        source_chunk_id: 1,
      },
    ],
    after: [
      {
        key: 'expense_small_auto',
        priority: 10,
        conditions: { field: 'payload.amount_eur', op: 'lte', value: 800 },
        actions: { decision: 'auto_approve' },
        source_quote: quote,
        source_chunk_id: 1,
      },
    ],
  },
  impact: {
    backtest: {
      kind: 'expense',
      total: 5,
      flipped_count: 2,
      summary: 'This would have changed 2 of 5 past expense decisions: 2 would have been auto-approved instead of sent for approval.',
      flipped: [
        { request_id: 1, requester_id: 3, payload: { amount_eur: 600 }, before: 'require_approval', after: 'auto_approve' },
        { request_id: 2, requester_id: 3, payload: { amount_eur: 700 }, before: 'require_approval', after: 'auto_approve' },
      ],
    },
  },
}

const people = new Map<number, Person>([
  [3, { id: 3, name: 'Ngozi Doe', email: 'n@nubo.test', title: 'Rep', department_id: 10, manager_id: 1, location: null, start_date: null, roles: [] }],
])

describe('RuleProposalDetails', () => {
  it('shows how many past decisions would flip, with the template sentence', () => {
    render(<RuleProposalDetails proposal={proposal} people={people} />)

    expect(screen.getByText('Decisions flipped').previousElementSibling).toHaveTextContent('2')
    expect(screen.getByText('Past requests replayed').previousElementSibling).toHaveTextContent('5')
    expect(screen.getByText(/would have changed 2 of 5 past expense decisions/)).toBeInTheDocument()
  })

  it('shows each rewritten rule before and after in plain English, with its handbook source', () => {
    render(<RuleProposalDetails proposal={proposal} people={people} />)

    const before = screen.getByRole('group', { name: 'expense_small_auto before' })
    const after = screen.getByRole('group', { name: 'expense_small_auto after' })
    expect(within(before).getByText(/amount ≤ €500/)).toBeInTheDocument()
    expect(within(after).getByText(/amount ≤ €800/)).toBeInTheDocument()
    expect(screen.getByText(quote)).toBeInTheDocument()
  })

  it('lists the flipped requests with who asked and how the outcome moved', () => {
    render(<RuleProposalDetails proposal={proposal} people={people} />)

    const rows = screen.getAllByRole('row').slice(1)
    expect(rows).toHaveLength(2)
    expect(within(rows[0]).getByText('Ngozi Doe')).toBeInTheDocument()
    expect(within(rows[0]).getByText('€600')).toBeInTheDocument()
    expect(within(rows[0]).getByText('Sent for approval → Auto-approved')).toBeInTheDocument()
  })

  it('says so when no past decision would change', () => {
    const quiet = { ...proposal, impact: { backtest: { ...proposal.impact.backtest, flipped_count: 0, flipped: [] } } }
    render(<RuleProposalDetails proposal={quiet} people={people} />)

    expect(screen.queryByRole('table')).not.toBeInTheDocument()
  })
})
