import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { AgentMarkdown } from './agent-markdown'

describe('AgentMarkdown', () => {
  it('renders headings, lists and bold text as elements, not raw syntax', () => {
    render(
      <AgentMarkdown>{`## Approval needed\n\n- **Tunde Bakare** must approve\n- Then it goes to finance`}</AgentMarkdown>,
    )

    expect(screen.getByRole('heading', { level: 2, name: 'Approval needed' })).toBeInTheDocument()
    const list = screen.getByRole('list')
    expect(list.querySelectorAll('li')).toHaveLength(2)
    expect(screen.getByText('Tunde Bakare').tagName).toBe('STRONG')
  })

  it('renders fenced code blocks as <pre><code>', () => {
    render(<AgentMarkdown>{'```json\n{"ok":true}\n```'}</AgentMarkdown>)

    const code = screen.getByText(/"ok":true/)
    expect(code.tagName).toBe('CODE')
    expect(code.closest('pre')).not.toBeNull()
  })
})
