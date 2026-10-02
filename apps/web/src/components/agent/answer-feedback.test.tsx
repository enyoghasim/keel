import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { AgentRun } from 'api-types'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { AnswerFeedback } from './answer-feedback'

const run: AgentRun = {
  id: 5,
  conversation_id: 'c1',
  person_id: 2,
  message: 'Can I expense a €1,200 flight?',
  status: 'completed',
  final_text: 'Yes.',
  total_tokens: 100,
  error_message: null,
  cost_usd: null,
  feedback: null,
  feedback_reason: null,
  created_at: '2026-10-02T10:00:00Z',
  steps: [],
}

function renderFeedback(current: AgentRun = run) {
  return render(
    <QueryClientProvider client={new QueryClient()}>
      <AnswerFeedback companyId="1" run={current} />
    </QueryClientProvider>,
  )
}

const ok = (data: AgentRun) => ({ body: { success: true, message: 'Thanks for the feedback.', data } })

describe('AnswerFeedback', () => {
  it('sends a thumbs-up straight away', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({ 'POST /api/companies/1/agent_runs/5/feedback': ok({ ...run, feedback: 'up' }) })
    renderFeedback()

    await user.click(screen.getByRole('button', { name: 'Good answer' }))

    expect(await screen.findByRole('button', { name: 'Good answer', pressed: true })).toBeInTheDocument()
    expect(JSON.parse(fetchMock.mock.calls[0][1]!.body as string)).toEqual({ rating: 'up' })
  })

  it('asks what was wrong on a thumbs-down, and sends the reason and note', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      'POST /api/companies/1/agent_runs/5/feedback': ok({ ...run, feedback: 'down', feedback_reason: 'wrong_answer' }),
    })
    renderFeedback()

    await user.click(screen.getByRole('button', { name: 'Bad answer' }))
    expect(fetchMock).not.toHaveBeenCalled()
    expect(screen.getByRole('group', { name: 'What was wrong?' })).toBeInTheDocument()

    await user.click(screen.getByRole('radio', { name: 'Wrong answer' }))
    await user.type(screen.getByLabelText('Anything else? (optional)'), 'It needs approval.')
    await user.click(screen.getByRole('button', { name: 'Send feedback' }))

    expect(await screen.findByText(/thanks/i)).toBeInTheDocument()
    expect(JSON.parse(fetchMock.mock.calls[0][1]!.body as string)).toEqual({
      rating: 'down',
      reason: 'wrong_answer',
      note: 'It needs approval.',
    })
  })

  it('shows feedback already given, without asking again', () => {
    renderFeedback({ ...run, feedback: 'down', feedback_reason: 'unclear' })

    expect(screen.getByRole('button', { name: 'Bad answer', pressed: true })).toBeInTheDocument()
    expect(screen.queryByRole('group', { name: 'What was wrong?' })).not.toBeInTheDocument()
  })

  it('shows the error when sending fails', async () => {
    const user = userEvent.setup()
    mockApi({ 'POST /api/companies/1/agent_runs/5/feedback': { status: 422, body: { success: false, message: 'Nope' } } })
    renderFeedback()

    await user.click(screen.getByRole('button', { name: 'Good answer' }))

    expect(await screen.findByText('Nope')).toBeInTheDocument()
  })
})
