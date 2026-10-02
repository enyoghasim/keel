import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it } from 'vitest'
import { renderApp } from '../../test/renderApp'

describe('Topbar', () => {
  beforeEach(() => {
    localStorage.clear()
    document.documentElement.classList.remove('dark')
  })

  it('renders the search trigger, trace button and person switcher', async () => {
    await renderApp('/assemble')

    expect(screen.getByRole('button', { name: /ask keel or search/i })).toBeInTheDocument()
    expect(screen.getByTitle('Agent trace')).toBeInTheDocument()
    expect(screen.getByText('Ifeoma Chukwu')).toBeInTheDocument()
    expect(screen.getByText('HR Admin')).toBeInTheDocument()
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
