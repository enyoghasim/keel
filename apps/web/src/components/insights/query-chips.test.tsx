import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { QueryChips } from './query-chips'

describe('QueryChips', () => {
  it('lists each part of the interpreted query as its own chip', () => {
    render(<QueryChips query={{ metric: 'leave_days', group_by: 'department', chart: 'bar' }} />)

    const chips = within(screen.getByRole('list', { name: 'How Keel understood the question' })).getAllByRole('listitem')
    expect(chips.map((chip) => chip.textContent)).toEqual(['Leave days', 'by department'])
  })
})
