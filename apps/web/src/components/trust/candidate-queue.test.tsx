import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { EvalCase } from 'api-types'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { CandidateQueue } from './candidate-queue'

const candidate: EvalCase = {
  id: 7,
  suite: 'agent',
  key: 'feedback_run_9',
  input: {
    message: 'Can I expense a €1,200 flight?',
    person_id: 3,
    agent_run_id: 9,
    observed: { final_text: 'Yes, auto-approved.', tool_calls: [{ name: 'check_policy', input: {}, output: { decision: 'require_approval' } }] },
  },
  expected: {},
  source: 'generated',
  status: 'candidate',
  notes: 'Thumbs-down (wrong answer): It needs manager approval.',
  created_at: '2026-10-02T10:00:00Z',
}

const path = 'GET /api/companies/1/eval_cases?status=candidate'
const list = (cases: EvalCase[]) => ({ [path]: { body: { success: true, message: '', data: cases } } })

function renderQueue(canReview = true) {
  return render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <CandidateQueue companyId="1" canReview={canReview} />
    </QueryClientProvider>,
  )
}

describe('CandidateQueue', () => {
  it('shows nothing when there are no candidates', async () => {
    mockApi(list([]))
    renderQueue()

    await screen.findByText('Candidate cases')
    expect(screen.getByText(/No candidates waiting/)).toBeInTheDocument()
  })

  it('shows what each production signal captured: the message, the answer, the tools it called and the note', async () => {
    mockApi(list([candidate]))
    renderQueue()

    const item = await screen.findByRole('listitem', { name: 'feedback_run_9' })
    expect(within(item).getByText('Can I expense a €1,200 flight?')).toBeInTheDocument()
    expect(within(item).getByText(/Thumbs-down \(wrong answer\): It needs manager approval\./)).toBeInTheDocument()
    expect(within(item).getByText('Agent')).toBeInTheDocument()
    expect(within(item).getByText(/Yes, auto-approved\./)).toBeInTheDocument()
    expect(within(item).getByText(/check_policy/)).toBeInTheDocument()
  })

  it('adds a case to the suite with the expected outcome the reviewer filled in', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      ...list([candidate]),
      'PATCH /api/companies/1/eval_cases/7': { body: { success: true, message: '', data: { ...candidate, status: 'active' } } },
    })
    renderQueue()

    const item = await screen.findByRole('listitem', { name: 'feedback_run_9' })
    const expected = within(item).getByLabelText('Expected outcome (JSON)')
    await user.clear(expected)
    await user.click(expected)
    await user.paste('{"tools":["check_policy"],"outputs":{"check_policy":{"decision":"require_approval"}}}')
    await user.click(within(item).getByRole('button', { name: 'Add to suite' }))

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/eval_cases/7',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({ status: 'active', expected: { tools: ['check_policy'], outputs: { check_policy: { decision: 'require_approval' } } } }),
      }),
    )
  })

  it("won't send an expected outcome that isn't valid JSON", async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi(list([candidate]))
    renderQueue()

    const item = await screen.findByRole('listitem', { name: 'feedback_run_9' })
    await user.click(within(item).getByLabelText('Expected outcome (JSON)'))
    await user.paste('{ nope')
    await user.click(within(item).getByRole('button', { name: 'Add to suite' }))

    expect(within(item).getByText(/isn't valid JSON/)).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledTimes(1) // just the list
  })

  it('archives a candidate', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      ...list([candidate]),
      'PATCH /api/companies/1/eval_cases/7': { body: { success: true, message: '', data: { ...candidate, status: 'archived' } } },
    })
    renderQueue()

    await user.click(await screen.findByRole('button', { name: 'Archive' }))

    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/eval_cases/7', expect.objectContaining({ body: JSON.stringify({ status: 'archived' }) }))
  })

  it('shows the API’s refusal, e.g. an empty expected outcome', async () => {
    const user = userEvent.setup()
    mockApi({
      ...list([candidate]),
      'PATCH /api/companies/1/eval_cases/7': { status: 422, body: { success: false, message: 'Fill in the expected outcome before adding this case to the suite.' } },
    })
    renderQueue()

    await user.click(await screen.findByRole('button', { name: 'Add to suite' }))

    expect(await screen.findByText('Fill in the expected outcome before adding this case to the suite.')).toBeInTheDocument()
  })

  it('is read-only for people who cannot review', async () => {
    mockApi(list([candidate]))
    renderQueue(false)

    await screen.findByRole('listitem', { name: 'feedback_run_9' })
    expect(screen.queryByRole('button', { name: 'Add to suite' })).not.toBeInTheDocument()
    expect(screen.queryByLabelText('Expected outcome (JSON)')).not.toBeInTheDocument()
  })
})
