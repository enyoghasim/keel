import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider, createMemoryHistory, createRouter } from '@tanstack/react-router'
import { render, waitFor, screen } from '@testing-library/react'
import { expect } from 'vitest'
import { routeTree } from '../router'

/**
 * Renders the whole app at a given path with a fresh router instance.
 *
 * Reusing the app's singleton router across tests (router.update() +
 * re-render) leaves stale pending-navigation state behind once a test's
 * render is unmounted, which hangs the next test's router.load(). A new
 * router per call sidesteps that entirely.
 */
export async function renderApp(path: string) {
  const router = createRouter({
    routeTree,
    history: createMemoryHistory({ initialEntries: [path] }),
  })
  await router.load()

  const view = render(
    <QueryClientProvider client={new QueryClient()}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  )

  // AuthGate shows a placeholder until the backend has said which company
  // this is and whether anyone is signed in; tests start from what follows.
  await waitFor(() => expect(screen.queryByText(/^(Loading…|Checking your session…)$/)).not.toBeInTheDocument())

  return { ...view, router }
}
