import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Ambiguity } from 'api-types'
import { describe, expect, it, vi } from 'vitest'
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

  it('reports the option a person picks', async () => {
    const user = userEvent.setup()
    const onAnswer = vi.fn()
    render(<AmbiguityBanner ambiguity={ambiguity} onAnswer={onAnswer} />)

    await user.click(screen.getByRole('button', { name: 'Travel and hotel' }))

    expect(onAnswer).toHaveBeenCalledWith('Travel and hotel')
  })

  it('shows the option being applied as pressed and disables every option meanwhile', () => {
    render(<AmbiguityBanner ambiguity={ambiguity} answering="Ticket only" />)

    expect(screen.getByRole('button', { name: 'Ticket only' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: 'Travel and hotel' })).toBeDisabled()
    expect(screen.getByText(/Updating the rule for “Ticket only”/)).toBeInTheDocument()
  })

  it('shows why an answer failed', () => {
    render(<AmbiguityBanner ambiguity={ambiguity} error="Only an hr_admin can do that." />)

    expect(screen.getByText('Only an hr_admin can do that.')).toBeInTheDocument()
  })
})
