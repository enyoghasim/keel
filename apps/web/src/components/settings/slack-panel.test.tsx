import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Integration } from 'api-types'
import { describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { SlackPanel } from './slack-panel'

const path = 'GET /api/companies/1/integrations'
const list = (integrations: Integration[]) => ({ [path]: { body: { success: true, message: '', data: integrations } } })

function renderPanel() {
  return render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <SlackPanel companyId="1" />
    </QueryClientProvider>,
  )
}

describe('SlackPanel', () => {
  it('shows a form to connect when nothing is connected yet', async () => {
    mockApi(list([]))
    renderPanel()

    expect(await screen.findByLabelText('Incoming webhook URL')).toBeInTheDocument()
    expect(screen.queryByText('Connected')).not.toBeInTheDocument()
  })

  it('connects with the pasted webhook URL', async () => {
    const user = userEvent.setup()
    const connected: Integration = { id: 9, kind: 'slack', status: 'connected', error_message: null, created_at: '2026-10-03T00:00:00Z' }
    const fetchMock = mockApi({
      [path]: [
        { body: { success: true, message: '', data: [] } },
        { body: { success: true, message: '', data: [connected] } },
      ],
      'POST /api/companies/1/integrations': { status: 201, body: { success: true, message: 'Slack connected.', data: connected } },
    })
    renderPanel()

    await user.type(await screen.findByLabelText('Incoming webhook URL'), 'https://hooks.slack.com/services/abc')
    await user.click(screen.getByRole('button', { name: 'Connect' }))

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/companies/1/integrations',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ kind: 'slack', webhook_url: 'https://hooks.slack.com/services/abc' }) }),
    )
    expect(await screen.findByText('Connected')).toBeInTheDocument()
  })

  it('shows Connected with a Disconnect button once Slack is already linked', async () => {
    mockApi(list([{ id: 9, kind: 'slack', status: 'connected', error_message: null, created_at: '2026-10-03T00:00:00Z' }]))
    renderPanel()

    expect(await screen.findByText('Connected')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Disconnect' })).toBeInTheDocument()
  })

  it('disconnects Slack', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      [path]: [
        { body: { success: true, message: '', data: [{ id: 9, kind: 'slack', status: 'connected', error_message: null, created_at: '2026-10-03T00:00:00Z' }] } },
        { body: { success: true, message: '', data: [] } },
      ],
      'DELETE /api/companies/1/integrations/9': { body: { success: true, message: 'Disconnected.' } },
    })
    renderPanel()

    await user.click(await screen.findByRole('button', { name: 'Disconnect' }))

    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/integrations/9', expect.objectContaining({ method: 'DELETE' }))
    expect(await screen.findByLabelText('Incoming webhook URL')).toBeInTheDocument()
  })

  it("shows the API's refusal, e.g. a bad webhook URL", async () => {
    const user = userEvent.setup()
    mockApi({
      ...list([]),
      'POST /api/companies/1/integrations': { status: 422, body: { success: false, message: "That doesn't look like a Slack incoming webhook URL." } },
    })
    renderPanel()

    await user.type(await screen.findByLabelText('Incoming webhook URL'), 'https://evil.example.com')
    await user.click(screen.getByRole('button', { name: 'Connect' }))

    expect(await screen.findByText(/doesn't look like a Slack/)).toBeInTheDocument()
  })
})
