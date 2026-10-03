import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import userEvent from '@testing-library/user-event'
import type { Integration, Person, Workflow, WorkflowEdit } from 'api-types'
import { describe, expect, it, vi } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { WorkflowEditor } from './workflow-editor'

const { subscriptionsCreate } = vi.hoisted(() => ({
  subscriptionsCreate: vi.fn((_channel: unknown, mixin: { received: (event: unknown) => void }) => {
    void mixin
    return { unsubscribe: vi.fn() }
  }),
}))
vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({ subscriptions: { create: subscriptionsCreate } })),
}))
const lastSubscription = () => subscriptionsCreate.mock.calls[subscriptionsCreate.mock.calls.length - 1]

const approval = { key: 'approval', type: 'approval' as const, assignee: undefined }
const notify = { key: 'hr_notify', type: 'notify' as const, title: 'Notify HR', assignee: 'role:hr_admin' }

function workflow(overrides: Partial<Workflow> = {}): Workflow {
  return {
    id: 5, name: 'Leave Workflow', status: 'draft', version: 1, trigger: { request_kind: 'leave' },
    steps: [ approval, notify ], created_at: '2026-10-01T00:00:00Z', ...overrides,
  }
}

const people: Person[] = []
const integrationsRoute = { 'GET /api/companies/1/integrations': { body: { success: true, message: '', data: [] as Integration[] } } }

function renderEditor(wf: Workflow) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={queryClient}>
      <WorkflowEditor companyId="1" workflow={wf} people={people} />
    </QueryClientProvider>,
  )
}

describe('WorkflowEditor', () => {
  it('starts collapsed behind an Edit steps button', () => {
    mockApi(integrationsRoute)
    renderEditor(workflow())

    expect(screen.getByRole('button', { name: 'Edit steps' })).toBeInTheDocument()
    expect(screen.queryByText('Editing steps')).not.toBeInTheDocument()
  })

  it('lists task/notify steps with reorder and edit controls, excluding approval', async () => {
    const user = userEvent.setup()
    mockApi(integrationsRoute)
    renderEditor(workflow())

    await user.click(screen.getByRole('button', { name: 'Edit steps' }))

    expect(screen.getAllByText('approval').length).toBeGreaterThan(0)
    expect(screen.getByText('Notify HR')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Move approval/ })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Move Notify HR up' })).toBeDisabled()
  })

  it('adds a step via the toolbar', async () => {
    const user = userEvent.setup()
    mockApi(integrationsRoute)
    renderEditor(workflow())

    await user.click(screen.getByRole('button', { name: 'Edit steps' }))
    await user.click(screen.getByRole('button', { name: '+ Add step' }))
    await user.click(await screen.findByText(/^Task/))

    expect(screen.getAllByText('task')).not.toHaveLength(0)
  })

  it('reorders a step without letting it swap past the approval step', async () => {
    const user = userEvent.setup()
    const task = { key: 'it_task', type: 'task' as const, title: 'IT setup', assignee: 'role:it_admin' }
    mockApi(integrationsRoute)
    renderEditor(workflow({ steps: [ approval, notify, task ] }))

    await user.click(screen.getByRole('button', { name: 'Edit steps' }))
    // "Notify HR" is the first editable row (approval has no move buttons) —
    // moving it up must be a no-op, never swapping it ahead of approval.
    expect(screen.getByRole('button', { name: 'Move Notify HR up' })).toBeDisabled()

    await user.click(screen.getByRole('button', { name: 'Move Notify HR down' }))

    const rows = screen.getAllByRole('listitem').map((row) => row.textContent)
    expect(rows[0]).toContain('approval')
    expect(rows[1]).toContain('IT setup')
    expect(rows[2]).toContain('Notify HR')
  })

  it('deletes a step from its edit panel', async () => {
    const user = userEvent.setup()
    mockApi(integrationsRoute)
    renderEditor(workflow())

    await user.click(screen.getByRole('button', { name: 'Edit steps' }))
    await user.click(screen.getByRole('button', { name: 'Edit' }))
    await user.click(screen.getByRole('button', { name: 'Delete step' }))

    expect(screen.queryByText('Notify HR')).not.toBeInTheDocument()
  })

  it('saves a draft workflow directly, with no proposal', async () => {
    const user = userEvent.setup()
    const saved = workflow({ version: 2 })
    const fetchMock = mockApi({
      ...integrationsRoute,
      'PATCH /api/companies/1/workflows/5': { body: { success: true, message: '', data: saved } },
    })
    renderEditor(workflow())

    await user.click(screen.getByRole('button', { name: 'Edit steps' }))
    await user.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => expect(screen.queryByText('Editing steps')).not.toBeInTheDocument())
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/workflows/5',
      expect.objectContaining({ method: 'PATCH', body: JSON.stringify({ steps: [ approval, notify ] }) }),
    )
  })

  // The post-proposed review UI (ProposedChange) renders a router <Link>,
  // so that part is covered end-to-end in routes/workflows.test.tsx, which
  // already has real router context set up. This stays at the trigger: an
  // active workflow's save goes to workflow_edits, not a direct PATCH.
  it('proposes a change for an active workflow instead of saving directly', async () => {
    const user = userEvent.setup()
    const pendingEdit: WorkflowEdit = {
      id: 40, workflow_id: 5, instruction: null, source: 'steps', status: 'pending',
      change_proposal_id: null, error_message: null, created_at: '2026-10-03T00:00:00Z',
    }
    const fetchMock = mockApi({
      ...integrationsRoute,
      'POST /api/companies/1/workflows/5/edits': { status: 202, body: { success: true, message: '', data: pendingEdit } },
    })
    renderEditor(workflow({ status: 'active' }))

    await user.click(screen.getByRole('button', { name: 'Edit steps' }))
    await user.click(screen.getByRole('button', { name: 'Edit' }))
    await user.click(screen.getByRole('button', { name: 'Delete step' }))
    await user.click(screen.getByRole('button', { name: 'Propose these steps' }))

    expect(await screen.findByRole('button', { name: 'Proposing…' })).toBeDisabled()
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/workflows/5/edits',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ steps: [ approval ] }) }),
    )
    expect(lastSubscription()[0]).toMatchObject({ channel: 'WorkflowEditChannel', workflow_edit_id: 40 })
  })
})
