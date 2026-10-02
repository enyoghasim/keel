import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { renderApp } from '../test/render-app'

describe('/ route', () => {
  it('redirects to /assemble', async () => {
    const { router } = await renderApp('/')

    expect(await screen.findByRole('heading', { name: 'Assemble' })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe('/assemble')
  })
})
