import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Integration } from 'api-types'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { CalendarPanel } from './calendar-panel'

const path = 'GET /api/companies/1/integrations'
const list = (integrations: Integration[]) => ({ [path]: { body: { success: true, message: '', data: integrations } } })
const connected: Integration = { id: 7, kind: 'google_calendar', status: 'connected', error_message: null, created_at: '2026-10-03T00:00:00Z' }

function renderPanel() {
  return render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <CalendarPanel companyId="1" />
    </QueryClientProvider>,
  )
}

describe('CalendarPanel', () => {
  afterEach(() => window.history.replaceState(null, '', '/settings'))

  it('shows a real link to the server-side OAuth authorize route when nothing is connected yet', async () => {
    mockApi(list([]))
    renderPanel()

    const link = await screen.findByRole('link', { name: 'Connect Google Calendar' })
    expect(link).toHaveAttribute('href', '/api/companies/1/integrations/google_calendar/authorize')
    expect(screen.queryByText('Connected')).not.toBeInTheDocument()
  })

  it('shows Connected with a Disconnect button once Calendar is already linked', async () => {
    mockApi(list([connected]))
    renderPanel()

    expect(await screen.findByText('Connected')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Disconnect' })).toBeInTheDocument()
  })

  it('disconnects Calendar', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({
      [path]: [{ body: { success: true, message: '', data: [connected] } }, { body: { success: true, message: '', data: [] } }],
      'DELETE /api/companies/1/integrations/7': { body: { success: true, message: 'Disconnected.' } },
    })
    renderPanel()

    await user.click(await screen.findByRole('button', { name: 'Disconnect' }))

    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/integrations/7', expect.objectContaining({ method: 'DELETE' }))
    expect(await screen.findByRole('link', { name: 'Connect Google Calendar' })).toBeInTheDocument()
  })

  describe('returning from a failed OAuth round trip', () => {
    beforeEach(() => window.history.replaceState(null, '', '/settings?calendar_error=Google%20declined%20the%20request.'))

    it('shows the error once and cleans it out of the URL', async () => {
      mockApi(list([]))
      renderPanel()

      expect(await screen.findByText('Google declined the request.')).toBeInTheDocument()
      expect(window.location.search).toBe('')
    })
  })
})
