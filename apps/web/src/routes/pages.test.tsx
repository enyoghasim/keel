import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { renderApp } from '../test/render-app'

const pages = [
  {
    path: '/workflows',
    heading: 'Workflows',
    note: /Workflows::Runtime and the workflow steps endpoint/,
  },
  {
    path: '/inbox',
    heading: 'Inbox',
    note: /Workflows::Runtime\.act and step_runs/,
  },
  {
    path: '/insights',
    heading: 'Insights',
    note: /Insights::Interpreter and QueryBuilder/,
  },
  {
    path: '/trust',
    heading: 'Trust',
    note: /Evals::Runner and eval_runs/,
  },
] as const

describe.each(pages)('$path', ({ path, heading, note }) => {
  it(`renders the ${heading} page`, async () => {
    await renderApp(path)

    expect(await screen.findByRole('heading', { name: heading })).toBeInTheDocument()
    expect(screen.getByText(note)).toBeInTheDocument()
  })
})
