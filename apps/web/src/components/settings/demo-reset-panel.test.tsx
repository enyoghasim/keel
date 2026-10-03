import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { mockApi } from '../../test/mock-api'
import { DemoResetPanel } from './demo-reset-panel'

function renderPanel() {
  return render(
    <QueryClientProvider client={new QueryClient()}>
      <DemoResetPanel companyId="1" />
    </QueryClientProvider>,
  )
}

describe('DemoResetPanel', () => {
  const assign = vi.fn()
  afterEach(() => vi.unstubAllGlobals())

  it('asks before wiping, and does nothing if cancelled', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({})
    renderPanel()

    await user.click(screen.getByRole('button', { name: 'Reset demo' }))
    expect(screen.getByText('Really wipe and reload?')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Cancel' }))

    expect(screen.getByRole('button', { name: 'Reset demo' })).toBeInTheDocument()
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('resets once confirmed and goes back to the start page', async () => {
    const user = userEvent.setup()
    const fetchMock = mockApi({ 'POST /api/companies/1/demo_reset': { body: { success: true, message: 'Demo reset to Demo Factorial.', data: {} } } })
    vi.stubGlobal('location', { ...window.location, assign })
    renderPanel()

    await user.click(screen.getByRole('button', { name: 'Reset demo' }))
    await user.click(screen.getByRole('button', { name: 'Yes, reset the demo' }))

    await waitFor(() => expect(assign).toHaveBeenCalledWith('/'))
    expect(fetchMock).toHaveBeenCalledWith('/api/companies/1/demo_reset', expect.objectContaining({ method: 'POST' }))
  })

  it('shows why it failed', async () => {
    const user = userEvent.setup()
    mockApi({ 'POST /api/companies/1/demo_reset': { status: 403, body: { success: false, message: 'Only an hr_admin can do that.' } } })
    renderPanel()

    await user.click(screen.getByRole('button', { name: 'Reset demo' }))
    await user.click(screen.getByRole('button', { name: 'Yes, reset the demo' }))

    expect(await screen.findByText('Only an hr_admin can do that.')).toBeInTheDocument()
  })
})
