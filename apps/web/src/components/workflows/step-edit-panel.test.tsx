import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Integration, WorkflowStep } from 'api-types'
import { describe, expect, it, vi } from 'vitest'
import { chooseOption } from '../../test/choose-option'
import { StepEditPanel } from './step-edit-panel'

const step: WorkflowStep = { key: 'hr_notify', type: 'notify', title: 'Notify HR', assignee: 'role:hr_admin' }

function renderPanel(overrides: Partial<Parameters<typeof StepEditPanel>[0]> = {}) {
  return render(
    <StepEditPanel step={step} integrations={[]} onChange={vi.fn()} onDelete={vi.fn()} onClose={vi.fn()} {...overrides} />,
  )
}

describe('StepEditPanel', () => {
  it('shows the step’s current fields', () => {
    renderPanel()

    expect(screen.getByLabelText('Title')).toHaveValue('Notify HR')
    expect(screen.getByLabelText('Assignee')).toHaveValue('role:hr_admin')
  })

  it('edits the title', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()
    renderPanel({ onChange })

    await user.type(screen.getByLabelText('Title'), '!')

    expect(onChange).toHaveBeenLastCalledWith({ ...step, title: 'Notify HR!' })
  })

  it('flags an assignee that is not a valid reference', () => {
    renderPanel({ step: { ...step, assignee: 'Tunde Bakare' } })

    expect(screen.getByText(/never a person's name/)).toBeInTheDocument()
  })

  it('disables an integration that is not connected, and enables one that is', async () => {
    const user = userEvent.setup()
    const integrations: Integration[] = [{ id: 1, kind: 'slack', status: 'connected', error_message: null, created_at: '2026-10-03T00:00:00Z' }]
    renderPanel({ integrations })

    await user.click(screen.getByLabelText('Integration'))

    expect(await screen.findByRole('option', { name: 'Slack' })).not.toHaveAttribute('data-disabled')
    expect(screen.getByRole('option', { name: /Google Calendar \(not connected\)/ })).toHaveAttribute('data-disabled')
  })

  it('binds the step to a connected integration', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()
    const integrations: Integration[] = [{ id: 1, kind: 'slack', status: 'connected', error_message: null, created_at: '2026-10-03T00:00:00Z' }]
    renderPanel({ integrations, onChange })

    await chooseOption(user, screen.getByLabelText('Integration'), 'Slack')

    expect(onChange).toHaveBeenLastCalledWith({ ...step, integration: { kind: 'slack' } })
  })

  it('calls onDelete', async () => {
    const user = userEvent.setup()
    const onDelete = vi.fn()
    renderPanel({ onDelete })

    await user.click(screen.getByRole('button', { name: 'Delete step' }))

    expect(onDelete).toHaveBeenCalled()
  })
})
