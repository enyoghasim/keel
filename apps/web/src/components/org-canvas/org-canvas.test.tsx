import { fireEvent, render, screen } from '@testing-library/react'
import type { Department, Person } from 'api-types'
import { describe, expect, it, vi } from 'vitest'
import { OrgCanvas } from './org-canvas'

// React Flow lays nodes out on a canvas-like SVG surface with real layout
// math (dagre) that jsdom can't meaningfully compute — positions, zoom and
// pan aren't worth asserting on here. What's worth testing at this boundary
// is that the component mounts without crashing on real data and that node
// selection wires through to the click handler; buildOrgGraph's own data
// transformation (edges, colors, layout ordering) is covered in
// org-graph.test.ts.
//
// Uses fireEvent.click rather than userEvent.click: userEvent's full pointer
// sequence includes a real mousedown, which the pane's d3-zoom pan-on-drag
// listener picks up and crashes on in jsdom (event.view is null there) —
// unrelated to anything this test is checking.

const people: Person[] = [
  {
    id: 1,
    name: 'Tunde Bakare',
    email: 'tunde@factorial.test',
    title: 'Sales Manager',
    department_id: 10,
    manager_id: null,
    location: null,
    start_date: null,
    roles: [],
  },
  {
    id: 2,
    name: 'Ngozi Doe',
    email: 'ngozi@factorial.test',
    title: 'Sales Rep',
    department_id: 10,
    manager_id: 1,
    location: null,
    start_date: null,
    roles: [],
  },
]

const departments: Department[] = [{ id: 10, name: 'Sales', head_id: 1 }]

describe('OrgCanvas', () => {
  it('mounts and renders a node per person, with name, title and department', async () => {
    render(<OrgCanvas people={people} departments={departments} />)

    expect(await screen.findByText('Tunde Bakare')).toBeInTheDocument()
    expect(screen.getByText('Sales Manager · Sales')).toBeInTheDocument()
    expect(screen.getByText('Ngozi Doe')).toBeInTheDocument()
  })

  it('calls onSelectPerson with the person id when a node is clicked', async () => {
    const onSelectPerson = vi.fn()
    render(<OrgCanvas people={people} departments={departments} onSelectPerson={onSelectPerson} />)

    fireEvent.click(await screen.findByText('Tunde Bakare'))

    expect(onSelectPerson).toHaveBeenCalledWith(1)
  })
})
