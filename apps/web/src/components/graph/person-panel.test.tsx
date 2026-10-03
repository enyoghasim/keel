import { render, screen } from '@testing-library/react'
import type { Department, Person } from 'api-types'
import { describe, expect, it } from 'vitest'
import { PersonPanel } from './person-panel'

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
  start_date: '2024-03-01',
  roles: [],
}

const sales: Department = { id: 10, name: 'Sales', head_id: 1 }

describe('PersonPanel', () => {
  it('shows a placeholder note when no person is selected', () => {
    render(<PersonPanel person={null} department={null} manager={null} />)

    expect(screen.getByText(/select a person/i)).toBeInTheDocument()
  })

  it("shows the selected person's name, title, department, manager and roles", () => {
    render(<PersonPanel person={report} department={sales} manager={manager} />)

    expect(screen.getByRole('heading', { name: 'Ngozi Doe' })).toBeInTheDocument()
    expect(screen.getByText('Sales Rep')).toBeInTheDocument()
    expect(screen.getByText('Sales')).toBeInTheDocument()
    expect(screen.getByText('Tunde Bakare')).toBeInTheDocument()
    expect(screen.getByText('Lagos')).toBeInTheDocument()
  })

  it('shows "No manager" for a person at the top of the tree', () => {
    render(<PersonPanel person={manager} department={sales} manager={null} />)

    expect(screen.getByText('No manager')).toBeInTheDocument()
    expect(screen.getByText('finance_lead')).toBeInTheDocument()
  })

  it('shows "No department" when the person has none', () => {
    const unassigned: Person = { ...manager, department_id: null }
    render(<PersonPanel person={unassigned} department={null} manager={null} />)

    expect(screen.getByText('No department')).toBeInTheDocument()
  })
})
