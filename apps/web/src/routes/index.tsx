import { createRoute } from '@tanstack/react-router'
import { Route as rootRoute } from './__root'

export const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  component: HomePage,
})

function HomePage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-zinc-50 text-zinc-900">
      <h1 className="text-2xl font-semibold">Keel</h1>
    </main>
  )
}
