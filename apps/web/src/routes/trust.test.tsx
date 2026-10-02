import { act, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { EvalResult, EvalRun, EvalRunWithResults, Person } from 'api-types'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { setCurrentCompanyId } from '../lib/current-company'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

// Same stable-spy setup as assemble.test.tsx and insights.test.tsx.
const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))

function person(roles: string[]): Person {
  return {
    id: 1,
    name: 'Ada Nwosu',
    email: 'ada@nubo.test',
    title: 'HR Admin',
    department_id: null,
    manager_id: null,
    location: null,
    start_date: null,
    roles,
  }
}

function envelope<T>(data: T, meta?: unknown) {
  return { body: { success: true, message: '', data, meta } }
}

const meta = { active_cases: { insights: 11 }, runnable_suites: ['insights'] }

function run(id: number, overrides: Partial<EvalRun> = {}): EvalRun {
  return {
    id,
    person_id: 1,
    suite: 'insights',
    status: 'completed',
    model: 'gpt-5.1',
    prompt_version_id: null,
    accuracy: 0.8,
    stability: null,
    stability_samples: 0,
    judge_score: null,
    judge_agreement: null,
    cost_usd: null,
    cases_count: 10,
    passed_count: 8,
    started_at: '2026-10-01T10:00:00Z',
    finished_at: '2026-10-01T10:01:00Z',
    error_message: null,
    created_at: `2026-10-0${id}T10:00:00Z`,
    ...overrides,
  }
}

function result(caseKey: string, question: string, passed: boolean, overrides: Partial<EvalResult> = {}): EvalResult {
  return {
    id: caseKey.length * 100 + (passed ? 1 : 0),
    eval_case_id: caseKey.length,
    case_key: caseKey,
    input: { question, today: '2026-10-02' },
    expected: { query: { metric: 'leave_days' } },
    passed,
    score: null,
    metrics: {},
    actual: { query: { metric: 'leave_days' } },
    diff: [],
    latency_ms: 420,
    error_message: null,
    ...overrides,
  }
}

const lastSubscription = () => subscriptionsCreate.mock.calls[subscriptionsCreate.mock.calls.length - 1]

describe('/trust', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when no company has been selected yet', async () => {
    await renderApp('/trust')

    expect(await screen.findByRole('heading', { name: 'Trust' })).toBeInTheDocument()
    expect(screen.getByText(/assemble one on the assemble page first/i)).toBeInTheDocument()
  })

  it('shows a scoreboard per suite and drills into the latest run, failures first with what differed', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const latest: EvalRunWithResults = {
      ...run(2, { accuracy: 0.5, passed_count: 1, cases_count: 2 }),
      results: [
        result('leave', 'Leave days by department last quarter', true),
        result('fiscal', 'Leave days last fiscal quarter', false, {
          expected: { clarification: true },
          diff: [{ field: 'clarification', expected: true, actual: { metric: 'leave_days' } }],
        }),
      ],
    }
    mockApi({
      'GET /api/companies/1/session': envelope(person(['hr_admin'])),
      'GET /api/companies/1/eval_runs': envelope([run(2, { accuracy: 0.5, passed_count: 1, cases_count: 2 }), run(1)], meta),
      'GET /api/companies/1/eval_runs/2': envelope(latest),
    })

    await renderApp('/trust')

    const insights = await screen.findByRole('region', { name: 'Insights suite' })
    expect(within(insights).getByText('50%')).toBeInTheDocument()
    expect(within(insights).getByText(/1 of 2 cases passed · gpt-5.1/)).toBeInTheDocument()
    expect(within(screen.getByRole('region', { name: 'Agent suite' })).getByText(/not runnable yet/i)).toBeInTheDocument()

    const detail = await screen.findByRole('region', { name: 'Run #2' })
    expect(within(detail).getByText('Failed (1)')).toBeInTheDocument()
    await user.click(within(detail).getByText('Leave days last fiscal quarter'))
    const differed = within(detail).getByRole('list', { name: 'Fields that differed' })
    expect(within(differed).getByText('clarification')).toBeInTheDocument()
    expect(within(detail).getByText('Passed (1)')).toBeInTheDocument()
  })

  it('starts a run and fills it in live from EvalChannel', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const pending = run(3, { status: 'pending', accuracy: null, cases_count: 0, passed_count: 0, model: null })
    const fetchMock = mockApi({
      'GET /api/companies/1/session': envelope(person(['hr_admin'])),
      'GET /api/companies/1/eval_runs': envelope([], meta),
      'POST /api/companies/1/eval_runs': { status: 202, body: { success: true, message: '', data: pending } },
      // Refetched once the run finishes, so the detail is reloaded whole.
      'GET /api/companies/1/eval_runs/3': [
        envelope({ ...pending, results: [] }),
        envelope({
          ...pending,
          status: 'completed',
          cases_count: 2,
          passed_count: 1,
          accuracy: 0.5,
          results: [
            result('leave', 'Leave days by department last quarter', true),
            result('fiscal', 'Leave days last fiscal quarter', false),
          ],
        }),
      ],
    })

    await renderApp('/trust')
    expect(await screen.findByText(/11 cases · not run yet/)).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Run insights suite' }))

    const detail = await screen.findByRole('region', { name: 'Run #3' })
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/eval_runs',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ suite: 'insights' }) }),
    )
    expect(screen.getByRole('button', { name: 'Run in progress…' })).toBeDisabled()
    expect(lastSubscription()[0]).toEqual({ channel: 'EvalChannel', eval_run_id: 3 })

    act(() => {
      lastSubscription()[1].received({ event: 'run', run: { ...pending, status: 'running', cases_count: 2 } })
      lastSubscription()[1].received({ event: 'result', result: result('leave', 'Leave days by department last quarter', true), done: 1, total: 2 })
    })
    expect(await within(detail).findByText('1 of 2 cases scored')).toBeInTheDocument()

    act(() =>
      lastSubscription()[1].received({ event: 'run', run: { ...pending, status: 'completed', cases_count: 2, passed_count: 1, accuracy: 0.5 } }),
    )
    expect(await within(detail).findByText('50% · 1 of 2 passed')).toBeInTheDocument()
  })

  it('compares two runs, listing the cases that flipped', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/session': envelope(person(['hr_admin'])),
      'GET /api/companies/1/eval_runs': envelope([run(2, { accuracy: 0.5 }), run(1, { accuracy: 0.5 })], meta),
      'GET /api/companies/1/eval_runs/1': envelope({
        ...run(1),
        results: [result('leave', 'Leave by department', true), result('fiscal', 'Leave last fiscal quarter', false)],
      }),
      'GET /api/companies/1/eval_runs/2': envelope({
        ...run(2),
        results: [result('leave', 'Leave by department', false), result('fiscal', 'Leave last fiscal quarter', true)],
      }),
    })

    await renderApp('/trust')
    await user.click(await screen.findByRole('checkbox', { name: 'Compare run #1' }))
    await user.click(screen.getByRole('checkbox', { name: 'Compare run #2' }))

    const comparison = await screen.findByRole('region', { name: 'Run comparison' })
    expect(within(comparison).getByText('Now passing (1)').nextElementSibling).toHaveTextContent('Leave last fiscal quarter')
    expect(within(comparison).getByText('Now failing (1)').nextElementSibling).toHaveTextContent('Leave by department')
  })

  it("hides the run button from someone who isn't an hr_admin", async () => {
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/session': envelope(person([])),
      'GET /api/companies/1/eval_runs': envelope([], meta),
    })

    await renderApp('/trust')

    expect(await screen.findByText('Only an hr_admin can start an eval run.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Run insights suite' })).not.toBeInTheDocument()
  })
})
