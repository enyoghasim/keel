# apps/web — Agent Guide

Vite + React 19 + TypeScript SPA. Read [docs/SPEC.md](../../docs/SPEC.md) section 14 before building a page for the first time.

## Structure

- `src/routes/` — one file per route (TanStack Router, code-based routing via `src/router.tsx`). A route file's only component export should be its page; shared pieces go in `src/components/`.
- `src/components/` — shared/reusable UI.
- `src/lib/` — `api.ts` (typed fetch client against `/api`), `cable.ts` (`useChannel` hook for Action Cable), `queryClient.ts`.

## Data fetching

All requests go through `src/lib/api.ts`. Wrap reads in TanStack Query (`useQuery`), writes in `useMutation`, and invalidate the relevant query keys after a mutation rather than refetching manually. Live updates (assemble progress, agent trace, eval progress) come over Action Cable via `useChannel`, not polling.

In dev, Vite proxies `/api` and `/cable` to Rails on `:3000` (see `vite.config.ts`) — don't hardcode a different host, and don't add CORS workarounds in dev; if you're hitting CORS, the proxy config is the bug.

## Testing

Vitest + Testing Library. Write the test against the rendered output a user would see (`getByRole`, `findByText`, ...) rather than implementation details. For a route, render it through the actual `router` with `createMemoryHistory` (see `src/routes/index.test.tsx`) rather than importing the page component directly — route files only export `Route`, not the component, so TanStack Router's file-based-routing convention and the fast-refresh lint rule both stay happy.

- `pnpm --filter web test` must be green before a commit.
- `oxlint` runs on staged `.ts`/`.tsx` files via lint-staged.

## Styling

Tailwind v4 (`@import "tailwindcss"` in `src/index.css`, loaded via the `@tailwindcss/vite` plugin — no `tailwind.config.js` needed). Neutral zinc palette plus one accent colour per SPEC.md section 14; dark mode via Tailwind's `dark:` variant.

## Shared types

Import request/response types from the `api-types` workspace package (generated from `packages/schemas` — run `pnpm gen:types` at the root after a schema changes) rather than redefining shapes the API already validates against.
