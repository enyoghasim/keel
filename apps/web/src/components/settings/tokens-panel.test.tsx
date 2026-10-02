import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { PersonalAccessToken } from 'api-types'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { TokensPanel } from './tokens-panel'

const token: PersonalAccessToken = { id: 4, name: 'Claude Desktop', last_used_at: '2026-10-02T10:00:00Z', revoked_at: null, created_at: '2026-10-01T10:00:00Z' }
const path = 'GET /api/companies/1/personal_access_tokens'
const list = (tokens: PersonalAccessToken[]) => ({ [path]: { body: { success: true, message: '', data: tokens } } })

function renderPanel() {
  return render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <TokensPanel companyId="1" />
    </QueryClientProvider>,
  )
}

describe('TokensPanel', () => {
  it('lists the person’s tokens with when they were last used, never their values', async () => {
    mockApi(list([token, { ...token, id: 5, name: 'Scratch', last_used_at: null }]))
    renderPanel()

    const claude = await screen.findByRole('listitem', { name: 'Claude Desktop' })
    expect(within(claude).getByText(/last used/i)).toBeInTheDocument()
    expect(within(screen.getByRole('listitem', { name: 'Scratch' })).getByText(/Never used/)).toBeInTheDocument()
  })

  it('creates a token and shows its value once, with the connection snippet', async () => {
    const user = userEvent.setup()
    const created = { ...token, id: 6, name: 'Laptop', last_used_at: null, token: 'keel_pat_abc123' }
    const fetchMock = mockApi({
      [path]: [
        { body: { success: true, message: '', data: [] } },
        { body: { success: true, message: '', data: [{ ...created, token: undefined }] } },
      ],
      'POST /api/companies/1/personal_access_tokens': { status: 201, body: { success: true, message: 'Token created.', data: created } },
    })
    renderPanel()

    await user.type(await screen.findByLabelText('Token name'), 'Laptop')
    await user.click(screen.getByRole('button', { name: 'Create token' }))

    const reveal = await screen.findByRole('alert')
    expect(within(reveal).getByText('keel_pat_abc123')).toBeInTheDocument()
    expect(within(reveal).getByText(/won't be shown again/i)).toBeInTheDocument()
    expect(screen.getByText(/Authorization/)).toHaveTextContent('Bearer keel_pat_abc123')
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/personal_access_tokens',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ name: 'Laptop' }) }),
    )
    expect(await screen.findByRole('listitem', { name: 'Laptop' })).toBeInTheDocument()
  })

  it('revokes a token', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      [path]: [
        { body: { success: true, message: '', data: [token] } },
        { body: { success: true, message: '', data: [] } },
      ],
      'DELETE /api/companies/1/personal_access_tokens/4': { body: { success: true, message: 'Token revoked.' } },
    })
    renderPanel()

    await user.click(await screen.findByRole('button', { name: 'Revoke Claude Desktop' }))

    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/personal_access_tokens/4', expect.objectContaining({ method: 'DELETE' }))
    expect(await screen.findByText(/no tokens yet/i)).toBeInTheDocument()
  })

  it('shows the API’s refusal, e.g. a missing name', async () => {
    const user = userEvent.setup()
    mockApi({
      ...list([]),
      'POST /api/companies/1/personal_access_tokens': { status: 422, body: { success: false, message: "Validation failed: Name can't be blank" } },
    })
    renderPanel()

    await user.click(await screen.findByRole('button', { name: 'Create token' }))

    expect(await screen.findByText(/Name can't be blank/)).toBeInTheDocument()
  })
})
