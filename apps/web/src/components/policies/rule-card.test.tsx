import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Rule } from 'api-types'
import { describe, expect, it } from 'vitest'
import { RuleCard } from './rule-card'

const rule: Rule = {
  id: 1,
  key: 'expense_conference_engineering',
  conditions: {
    all: [
      { field: 'requester.department', op: 'eq', value: 'Engineering' },
      { field: 'payload.category', op: 'eq', value: 'conference' },
      { field: 'payload.amount_eur', op: 'lte', value: 1000 },
    ],
  },
  actions: { decision: 'auto_approve' },
  priority: 10,
  source_quote: 'Engineers attending conferences are automatically approved up to €1,000.',
  ambiguities: [],
  status: 'active',
  policy_id: 1,
}

describe('RuleCard', () => {
  it('renders the rule in plain English, its priority and status', () => {
    render(<RuleCard rule={rule} matched={false} onHover={() => {}} />)

    expect(
      screen.getByText('If department is Engineering and category is conference and amount ≤ €1,000 → auto-approve'),
    ).toBeInTheDocument()
    expect(screen.getByText('Priority 10')).toBeInTheDocument()
    expect(screen.getByText('Active')).toBeInTheDocument()
  })

  it('reveals the raw JSON when "Show JSON" is clicked', async () => {
    const user = userEvent.setup()
    render(<RuleCard rule={rule} matched={false} onHover={() => {}} />)

    expect(screen.queryByText(/"decision": "auto_approve"/)).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Show JSON' }))

    expect(screen.getByText(/"decision": "auto_approve"/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Hide JSON' })).toBeInTheDocument()
  })

  it('shows an ambiguity banner for each open ambiguity', () => {
    const withAmbiguity: Rule = {
      ...rule,
      ambiguities: [{ phrase: 'up to €1,000', question: 'Does that cover hotel too?', options: ['Yes', 'No'] }],
    }

    render(<RuleCard rule={withAmbiguity} matched={false} onHover={() => {}} />)

    expect(screen.getByText('Does that cover hotel too?')).toBeInTheDocument()
  })

  it('calls onHover with the rule id on mouse enter and null on leave', async () => {
    const user = userEvent.setup()
    const hovered: (number | null)[] = []
    render(<RuleCard rule={rule} matched={false} onHover={(id) => hovered.push(id)} />)

    await user.hover(screen.getByText(/If department is Engineering/))
    await user.unhover(screen.getByText(/If department is Engineering/))

    expect(hovered).toEqual([1, null])
  })
})
