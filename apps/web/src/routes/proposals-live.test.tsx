import { act, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { OrgChangeProposal } from 'api-types'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

// Its own file because Action Cable subscriptions are shared per channel
// and params for the life of the module (see lib/cable.ts).
const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))

const proposal: OrgChangeProposal = {
  id: 1,
  company_id: 1,
  kind: 'org',
  title: 'Move Ngozi under Ada',
  diff: [{ op: 'change_manager', person_id: 3, from: 1, to: 2 }],
  impact: { rerouted: [], broken: [], self_approval: [], approval_load_changes: [], rerouted_in_flight: [] },
  proposed_by: 'agent',
  agent_run_id: null,
  status: 'pending',
  decided_by_id: null,
  decided_at: null,
  explanation: null,
  created_at: '2026-01-01T00:00:00Z',
}
const me = { id: 99, name: 'Chiamaka Eze', email: 'c@factorial.test', title: 'HR Admin', department_id: null, manager_id: null, location: null, start_date: null, roles: ['hr_admin'] }
const ok = (data: unknown) => ({ body: { success: true, message: '', data } })

describe('/proposals live updates', () => {
  beforeEach(() => localStorage.clear())

  it('fills the explanation in when the API finishes writing it, without a reload', async () => {
    const user = userEvent.setup()
    const path = 'GET /api/companies/1/change_proposals'
    mockApi({
      [path]: [ok([proposal]), ok([{ ...proposal, explanation: 'Ada takes on Ngozi’s approvals.' }])],
      'GET /api/companies/1/people': ok([]),
      'GET /api/companies/1/departments': ok([]),
      'GET /api/companies/1/session': ok(me),
    })

    await renderApp('/proposals')
    await user.click(await screen.findByRole('button', { name: /Move Ngozi under Ada/ }))
    expect(screen.queryByRole('region', { name: 'In plain English' })).not.toBeInTheDocument()

    const subscription = subscriptionsCreate.mock.calls.find(([params]) => (params as { channel: string }).channel === 'ChangeProposalChannel')
    expect(subscription?.[0]).toMatchObject({ company_id: '1' })
    act(() => subscription?.[1].received({ id: 1, explanation: 'Ada takes on Ngozi’s approvals.' }))

    expect(await screen.findByText('Ada takes on Ngozi’s approvals.')).toBeInTheDocument()
  })
})
