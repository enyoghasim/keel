import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Person, Workflow, WorkflowTestRunResult } from 'api-types'
import { beforeEach, describe, expect, it } from 'vitest'
import { setCurrentCompanyId } from '../lib/current-company'
import { mockApi } from '../test/mock-api'
import { renderApp } from '../test/render-app'

const expenseWorkflow: Workflow = {
  id: 5,
  name: 'Expense approval',
  status: 'active',
  trigger: { request_kind: 'expense' },
  steps: [
    { key: 'approval', type: 'approval' },
    {
      key: 'notify_finance',
      type: 'notify',
      title: 'Notify finance',
      assignee: 'role:finance_lead',
      when: { field: 'payload.amount_eur', op: 'gt', value: 1000 },
    },
  ],
  created_at: '2026-01-01T00:00:00Z',
}

const leaveWorkflow: Workflow = {
  id: 6,
  name: 'Leave approval',
  status: 'draft',
  trigger: { request_kind: 'leave' },
  steps: [{ key: 'approval', type: 'approval' }],
  created_at: '2026-01-02T00:00:00Z',
}

const requester: Person = {
  id: 2,
  name: 'Ngozi Doe',
  email: 'ngozi@nubo.test',
  title: 'Sales Rep',
  department_id: null,
  manager_id: null,
  location: null,
  start_date: null,
  roles: [],
}
const peopleRoute = { 'GET /api/companies/1/people': { body: { success: true, message: '', data: [requester] } } }

const currentPerson: Person = {
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
const sessionRoute = { 'GET /api/companies/1/session': { body: { success: true, message: '', data: currentPerson } } }

describe('/workflows', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('shows an empty state when no company has been selected yet', async () => {
    await renderApp('/workflows')

    expect(await screen.findByRole('heading', { name: 'Workflows' })).toBeInTheDocument()
    expect(screen.getByText(/assemble one on the assemble page first/i)).toBeInTheDocument()
  })

  it('shows an empty state when the company has no workflows', async () => {
    setCurrentCompanyId('1')
    mockApi({ 'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [] } }, ...sessionRoute })

    await renderApp('/workflows')

    expect(await screen.findByText(/no workflows yet/i)).toBeInTheDocument()
  })

  it('shows the first workflow selected, with its trigger and steps on the graph', async () => {
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow, leaveWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')

    expect(await screen.findByRole('tab', { name: /Expense approval/ })).toHaveAttribute('aria-selected', 'true')
    expect(await screen.findByText('Expense request submitted')).toBeInTheDocument()
    expect(screen.getByText('Notify finance')).toBeInTheDocument()
  })

  it('switches workflows when a different tab is picked', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow, leaveWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      'GET /api/companies/1/workflows/6': { body: { success: true, message: '', data: leaveWorkflow } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')
    await screen.findByText('Expense request submitted')

    await user.click(screen.getByRole('tab', { name: /Leave approval/ }))

    expect(await screen.findByText('Leave request submitted')).toBeInTheDocument()
  })

  it('runs a test run and lights up the matched steps with the resolved person', async () => {
    const user = userEvent.setup()
    setCurrentCompanyId('1')
    const testRunResult: WorkflowTestRunResult = {
      outcome: 'require_approval',
      matched_rule_keys: ['big_expense'],
      errors: [],
      steps: [
        { step_key: 'approval', type: 'approval', reference: 'person:2', resolved_person_id: 2, matched: true },
        { step_key: 'notify_finance', type: 'notify', reference: 'role:finance_lead', resolved_person_id: null, matched: true },
      ],
    }
    mockApi({
      'GET /api/companies/1/workflows': { body: { success: true, message: '', data: [expenseWorkflow] } },
      'GET /api/companies/1/workflows/5': { body: { success: true, message: '', data: expenseWorkflow } },
      'POST /api/companies/1/workflows/5/test_run': { body: { success: true, message: '', data: testRunResult } },
      ...peopleRoute,
      ...sessionRoute,
    })

    await renderApp('/workflows')
    await screen.findByText('Expense request submitted')

    await user.click(screen.getByRole('button', { name: 'Test run' }))
    await user.selectOptions(await screen.findByLabelText('Requester'), 'Ngozi Doe')
    await user.type(screen.getByLabelText('Amount (EUR)'), '1500')
    await user.click(screen.getByRole('button', { name: 'Run test' }))

    expect(await screen.findByText('Needs approval')).toBeInTheDocument()
    expect(screen.getByText('Ngozi Doe')).toBeInTheDocument()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })
})
