import { vi } from 'vitest'

interface MockedResponse {
  status?: number
  body: unknown
}

type RouteTable = Record<string, MockedResponse | MockedResponse[]>

/**
 * Mocks `fetch` at the network boundary for src/lib/api.ts's request client.
 * `routes` maps "METHOD /api/path" to the JSON body (and optional status,
 * default 200) to respond with. A list of responses is consumed in order,
 * one per call, repeating the last entry once exhausted — useful for
 * asserting a refetch after a mutation sees updated data. Throws if a
 * request isn't in the table, so an unmocked call fails loudly instead of
 * hanging.
 *
 * Every app render first asks GET /api/workspace which company the
 * deployment serves; unless a test mocks it, that answers "company 1".
 */
export const workspaceWithCompany = { body: { success: true, message: '', data: { company: { id: 1, name: 'Nubo', assembling: false } } } }
export const workspaceWithoutCompany = { body: { success: true, message: '', data: { company: null } } }

export function mockApi(userRoutes: RouteTable) {
  const routes: RouteTable = { 'GET /api/workspace': workspaceWithCompany, ...userRoutes }
  const calls = new Map<string, number>()

  const fetchMock = vi.fn(async (url: string | URL, init?: RequestInit) => {
    const key = `${init?.method ?? 'GET'} ${url}`
    const mocked = routes[key]
    if (!mocked) throw new Error(`mockApi: no mocked response for "${key}"`)

    const sequence = Array.isArray(mocked) ? mocked : [mocked]
    const callIndex = calls.get(key) ?? 0
    calls.set(key, callIndex + 1)
    const response = sequence[Math.min(callIndex, sequence.length - 1)]

    return {
      ok: (response.status ?? 200) < 400,
      status: response.status ?? 200,
      json: async () => response.body,
    } as Response
  })

  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}
