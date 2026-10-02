import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { EvalRun, PromptVersion } from 'api-types'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { PromptVersions } from './prompt-versions'

const completedRun = (accuracy: number, overrides: Partial<EvalRun> = {}): EvalRun => ({
  id: 1,
  person_id: 1,
  suite: 'policy_extraction',
  status: 'completed',
  model: 'gpt-5.1',
  prompt_version_id: 1,
  accuracy,
  stability: null,
  stability_samples: 0,
  judge_score: null,
  judge_agreement: null,
  cost_usd: null,
  cases_count: 12,
  passed_count: 6,
  started_at: null,
  finished_at: '2026-10-01T10:01:00Z',
  error_message: null,
  created_at: '2026-10-01T10:00:00Z',
  ...overrides,
})

const v2: PromptVersion = {
  id: 2,
  key: 'policy_extractor',
  version: 2,
  model: null,
  active: true,
  notes: 'Requires verbatim source quotes.',
  created_at: '2026-10-02T00:00:00Z',
  latest_run: completedRun(0.9167, { id: 2, prompt_version_id: 2, stability: 0.96, stability_samples: 5 }),
  regressions: [],
}
const v1: PromptVersion = {
  id: 1,
  key: 'policy_extractor',
  version: 1,
  model: null,
  active: false,
  notes: 'First draft.',
  created_at: '2026-10-01T00:00:00Z',
  latest_run: completedRun(0.5),
  regressions: ['nubo_leave', 'meals_daily_cap'],
}

function renderPanel(canPromote = true) {
  return render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <PromptVersions companyId="1" canPromote={canPromote} />
    </QueryClientProvider>,
  )
}

const list = (versions: PromptVersion[]) => ({
  'GET /api/companies/1/prompt_versions': { body: { success: true, message: '', data: versions } },
})

describe('PromptVersions', () => {
  it('lists each version with its notes, accuracy and stability, marking the active one', async () => {
    mockApi(list([v2, v1]))
    renderPanel()

    const panel = await screen.findByRole('region', { name: 'Prompt versions' })
    const active = within(panel).getByRole('listitem', { name: 'policy_extractor v2' })
    expect(within(active).getByText('Active')).toBeInTheDocument()
    expect(within(active).getByText('Requires verbatim source quotes.')).toBeInTheDocument()
    expect(within(active).getByText(/91.7% accuracy/)).toBeInTheDocument()
    expect(within(active).getByText(/96% stable/)).toBeInTheDocument()
    expect(within(active).queryByRole('button', { name: /Promote/ })).not.toBeInTheDocument()
  })

  it("warns which cases a challenger would regress, and says so when it hasn't been evaluated", async () => {
    mockApi(list([v2, { ...v1, latest_run: null, regressions: null }]))
    renderPanel()
    expect(await screen.findByText('Not evaluated yet — run the suite with this version first.')).toBeInTheDocument()

    mockApi(list([v2, v1]))
    renderPanel()
    expect((await screen.findAllByText(/Would regress 2 cases: nubo_leave, meals_daily_cap/))[0]).toBeInTheDocument()
  })

  it('promotes a challenger, then refreshes the list', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      'GET /api/companies/1/prompt_versions': [
        { body: { success: true, message: '', data: [{ ...v2, active: false, regressions: [] }, { ...v1, active: true, regressions: [] }] } },
        { body: { success: true, message: '', data: [v2, { ...v1, active: false }] } },
      ],
      'POST /api/companies/1/prompt_versions/2/promote': { body: { success: true, message: 'Version 2 is now active.', data: v2 } },
    })
    renderPanel()

    await user.click(await screen.findByRole('button', { name: 'Promote v2' }))

    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/prompt_versions/2/promote', expect.objectContaining({ method: 'POST', body: JSON.stringify({}) }))
    expect(await screen.findByRole('listitem', { name: 'policy_extractor v2' })).toHaveTextContent('Active')
  })

  it('offers "Promote anyway" when the API refuses over regressions, and sends confirm', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      'GET /api/companies/1/prompt_versions': { body: { success: true, message: '', data: [{ ...v2, active: false, regressions: [] }, { ...v1, active: true, regressions: [] }] } },
      'POST /api/companies/1/prompt_versions/2/promote': [
        { status: 422, body: { success: false, message: 'This version regresses 1 case the active version passes: nubo_leave.', errors: ['nubo_leave'] } },
        { body: { success: true, message: 'ok', data: v2 } },
      ],
    })
    renderPanel()

    await user.click(await screen.findByRole('button', { name: 'Promote v2' }))
    expect(await screen.findByText(/regresses 1 case the active version passes: nubo_leave/)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Promote anyway' }))

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/prompt_versions/2/promote',
      expect.objectContaining({ body: JSON.stringify({ confirm: true }) }),
    )
  })

  it('hides Promote from people who cannot use it', async () => {
    mockApi(list([{ ...v2, active: false }, { ...v1, active: true }]))
    renderPanel(false)

    await screen.findByRole('region', { name: 'Prompt versions' })
    expect(screen.queryByRole('button', { name: /Promote/ })).not.toBeInTheDocument()
  })
})
