import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Envelope, Person } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { setCurrentCompanyId } from '../../lib/current-company'
import { mockApi } from '../../test/mock-api'
import { renderApp } from '../../test/render-app'

const ada: Person = {
  id: 1,
  name: 'Ada Nwosu',
  email: 'ada@nubo.test',
  title: 'HR Admin',
  department_id: null,
  manager_id: null,
  location: null,
  start_date: null,
  roles: ['hr_admin'],
}

const signedInRoute = {
  'GET /api/companies/1/session': { body: { success: true, message: '', data: ada } as Envelope<Person> },
}

describe('Topbar', () => {
  beforeEach(() => {
    localStorage.clear()
    document.documentElement.classList.remove('dark')
  })

  it('renders the search trigger and trace button', async () => {
    await renderApp('/assemble')

    expect(screen.getByRole('button', { name: /ask keel or search/i })).toBeInTheDocument()
    expect(screen.getByTitle('Agent trace')).toBeInTheDocument()
  })

  it('shows no person chip when no one is signed in', async () => {
    await renderApp('/assemble')

    expect(screen.queryByTitle('Sign out')).not.toBeInTheDocument()
  })

  it('shows the signed-in person once a session is active', async () => {
    setCurrentCompanyId('1')
    mockApi(signedInRoute)

    await renderApp('/assemble')

    expect(await screen.findByText('Ada Nwosu')).toBeInTheDocument()
    expect(screen.getByText('HR Admin')).toBeInTheDocument()
    expect(screen.getByText('AN')).toBeInTheDocument()
  })

  it('signs the person out when the chip is clicked', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/session': [
        { body: { success: true, message: '', data: ada } },
        { status: 401, body: { success: false, message: 'Not signed in.' } },
      ],
      'DELETE /api/companies/1/session': { body: { success: true, message: 'Signed out.' } },
    })

    await renderApp('/assemble')
    await screen.findByTitle('Sign out')

    await user.click(screen.getByTitle('Sign out'))

    await waitFor(() => expect(screen.queryByTitle('Sign out')).not.toBeInTheDocument())
  })

  it('toggles the theme class on the root element when clicked', async () => {
    const user = userEvent.setup()
    await renderApp('/assemble')

    expect(document.documentElement.classList.contains('dark')).toBe(false)

    await user.click(screen.getByTitle('Toggle theme'))
    expect(document.documentElement.classList.contains('dark')).toBe(true)

    await user.click(screen.getByTitle('Toggle theme'))
    expect(document.documentElement.classList.contains('dark')).toBe(false)
  })
})
