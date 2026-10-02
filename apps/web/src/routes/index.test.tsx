import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider, createMemoryHistory } from '@tanstack/react-router'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { router } from '../router'

describe('/ route', () => {
  it('renders the Keel heading', async () => {
    router.update({ history: createMemoryHistory({ initialEntries: ['/'] }) })
    await router.load()

    render(
      <QueryClientProvider client={new QueryClient()}>
        <RouterProvider router={router} />
      </QueryClientProvider>,
    )

    expect(await screen.findByRole('heading', { name: 'Keel' })).toBeInTheDocument()
  })
})
