import { render, screen } from '@testing-library/react'
import type { Rule } from 'api-types'
import { describe, expect, it } from 'vitest'
import { HandbookPane } from './handbook-pane'

function rule(id: number, source_quote: string): Rule {
  return {
    id,
    key: `rule_${id}`,
    conditions: { field: 'payload.amount_eur', op: 'lte', value: 1000 },
    actions: { decision: 'auto_approve' },
    priority: 1,
    source_quote,
    ambiguities: [],
    status: 'active',
    policy_id: 1,
  }
}

describe('HandbookPane', () => {
  it('shows a placeholder when the policy has no rules yet', () => {
    render(<HandbookPane rules={[]} highlightedRuleId={null} />)

    expect(screen.getByText(/no handbook text yet/i)).toBeInTheDocument()
  })

  it('shows each rule source quote', () => {
    render(
      <HandbookPane
        rules={[rule(1, 'Engineers may expense conferences up to €1,000.'), rule(2, 'Travel under €800 is auto-approved.')]}
        highlightedRuleId={null}
      />,
    )

    expect(screen.getByText(/Engineers may expense conferences up to €1,000\./)).toBeInTheDocument()
    expect(screen.getByText(/Travel under €800 is auto-approved\./)).toBeInTheDocument()
  })

  it('highlights the quote matching the hovered rule id', () => {
    render(
      <HandbookPane
        rules={[rule(1, 'Engineers may expense conferences up to €1,000.'), rule(2, 'Travel under €800 is auto-approved.')]}
        highlightedRuleId={2}
      />,
    )

    expect(screen.getByTestId('source-quote-2').className).toContain('border-brand')
    expect(screen.getByTestId('source-quote-1').className).not.toContain('border-brand')
  })
})
