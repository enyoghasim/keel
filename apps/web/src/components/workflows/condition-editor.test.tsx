import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { chooseOption } from '../../test/choose-option'
import { ConditionEditor } from './condition-editor'

describe('ConditionEditor', () => {
  it('starts with no condition, just a checkbox', () => {
    render(<ConditionEditor condition={undefined} onChange={vi.fn()} />)

    expect(screen.getByRole('checkbox')).not.toBeChecked()
    expect(screen.queryByLabelText('Condition field')).not.toBeInTheDocument()
  })

  it('reveals the field/op/value row once checked, with a sensible default', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()
    render(<ConditionEditor condition={undefined} onChange={onChange} />)

    await user.click(screen.getByRole('checkbox'))

    expect(onChange).toHaveBeenCalledWith({ field: 'payload.amount_eur', op: 'gt', value: 0 })
  })

  it('shows a live plain-English preview that updates as the condition changes', () => {
    const { rerender } = render(<ConditionEditor condition={{ field: 'payload.days', op: 'gt', value: 3 }} onChange={vi.fn()} />)

    expect(screen.getByText('days > 3')).toBeInTheDocument()

    rerender(<ConditionEditor condition={{ field: 'payload.days', op: 'gt', value: 5 }} onChange={vi.fn()} />)

    expect(screen.getByText('days > 5')).toBeInTheDocument()
  })

  it('switches to two number inputs for "is between"', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()
    render(<ConditionEditor condition={{ field: 'payload.days', op: 'gt', value: 3 }} onChange={onChange} />)

    await chooseOption(user, screen.getByLabelText('Condition operator'), 'is between')

    expect(onChange).toHaveBeenCalledWith({ field: 'payload.days', op: 'between', value: 3 })
  })

  it('shows a comma-separated input for "is one of", parsed back into an array', () => {
    const onChange = vi.fn()
    render(<ConditionEditor condition={{ field: 'requester.department', op: 'in', value: [ 'Sales' ] }} onChange={onChange} />)

    const input = screen.getByLabelText('Values, comma-separated')
    expect(input).toHaveValue('Sales')

    fireEvent.change(input, { target: { value: 'Sales, Engineering' } })

    expect(onChange).toHaveBeenLastCalledWith({ field: 'requester.department', op: 'in', value: [ 'Sales', 'Engineering' ] })
  })

  it('unchecking clears the condition', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()
    render(<ConditionEditor condition={{ field: 'payload.days', op: 'gt', value: 3 }} onChange={onChange} />)

    await user.click(screen.getByRole('checkbox'))

    expect(onChange).toHaveBeenCalledWith(undefined)
  })
})
