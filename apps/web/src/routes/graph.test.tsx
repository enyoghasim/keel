import { fireEvent, screen } from '@testing-library/react'
import type { Department, Person } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

const manager: Person = {
  id: 1,
  name: 'Tunde Bakare',
  email: 'tunde@factorial.test',
  title: 'Sales Manager',
  department_id: 10,
  manager_id: null,
  location: null,
  start_date: null,
  roles: ['finance_lead'],
}

const report: Person = {
  id: 2,
  name: 'Ngozi Doe',
  email: 'ngozi@factorial.test',
  title: 'Sales Rep',
  department_id: 10,
  manager_id: 1,
  location: 'Lagos',
  start_date: null,
  roles: [],
}

const departments: Department[] = [{ id: 10, name: 'Sales', head_id: 1 }]

const peopleRoute = { 'GET /api/companies/1/people': { body: { success: true, message: '', data: [manager, report] } } }
const departmentsRoute = {
  'GET /api/companies/1/departments': { body: { success: true, message: '', data: departments } },
}
// A distinct person from the chart data above — reusing `manager` here would
// make it appear once more as the Topbar's signed-in chip, breaking assertions
// that count how many times "Tunde Bakare" appears in the chart itself.
const currentPerson: Person = {
  id: 99,
  name: 'Chiamaka Eze',
  email: 'chiamaka@factorial.test',
  title: 'HR Admin',
  department_id: null,
  manager_id: null,
  location: null,
  start_date: null,
  roles: ['hr_admin'],
}
const sessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: currentPerson } } }

describe('/graph', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when the company has no people yet', async () => {
    mockApi({
      'GET /api/companies/1/people': { body: { success: true, message: '', data: [] } },
      ...departmentsRoute,
      ...sessionRoute,
    })

    await renderApp('/graph')

    expect(await screen.findByText(/no people yet/i)).toBeInTheDocument()
  })

  it('renders the org chart with a placeholder panel until a person is selected', async () => {
    mockApi({ ...peopleRoute, ...departmentsRoute, ...sessionRoute })

    await renderApp('/graph')

    expect(await screen.findByText('Tunde Bakare')).toBeInTheDocument()
    expect(screen.getByText('Ngozi Doe')).toBeInTheDocument()
    expect(screen.getByText(/select a person on the chart/i)).toBeInTheDocument()
  })

  it('shows the selected person in the panel on node click', async () => {
    mockApi({ ...peopleRoute, ...departmentsRoute, ...sessionRoute })

    await renderApp('/graph')
    fireEvent.click(await screen.findByText('Ngozi Doe'))

    expect(await screen.findByRole('heading', { name: 'Ngozi Doe' })).toBeInTheDocument()
    expect(screen.getByText('Sales Rep')).toBeInTheDocument()
    expect(screen.getByText('Lagos')).toBeInTheDocument()
    // "Tunde Bakare" appears twice now: once as a chart node, once as the
    // resolved manager name in the panel.
    expect(screen.getAllByText('Tunde Bakare')).toHaveLength(2)
  })

  it('has a colour-by-department toggle that starts checked', async () => {
    mockApi({ ...peopleRoute, ...departmentsRoute, ...sessionRoute })

    await renderApp('/graph')
    await screen.findByText('Tunde Bakare')

    const toggle = screen.getByRole('checkbox', { name: /colour by department/i })
    expect(toggle).toBeChecked()

    fireEvent.click(toggle)
    expect(toggle).not.toBeChecked()
  })
})
