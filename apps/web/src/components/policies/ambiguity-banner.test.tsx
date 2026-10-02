import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Ambiguity } from 'api-types'
import { describe, expect, it } from 'vitest'
import { AmbiguityBanner } from './ambiguity-banner'

const ambiguity: Ambiguity = {
  phrase: 'up to €1,000',
  question: 'Does the €1,000 cover travel and hotel, or only the ticket?',
  options: ['Ticket only', 'Travel and hotel'],
}

describe('AmbiguityBanner', () => {
  it('shows the question and each option as a button', () => {
    render(<AmbiguityBanner ambiguity={ambiguity} />)

    expect(screen.getByText(ambiguity.question)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Ticket only' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Travel and hotel' })).toBeInTheDocument()
  })

  it('explains that resolution is not wired up yet once an option is chosen', async () => {
    const user = userEvent.setup()
    render(<AmbiguityBanner ambiguity={ambiguity} />)

    await user.click(screen.getByRole('button', { name: 'Travel and hotel' }))

    expect(screen.getByText(/selected "travel and hotel"/i)).toBeInTheDocument()
    expect(screen.getByText(/isn't wired up in the api yet/i)).toBeInTheDocument()
  })
})
