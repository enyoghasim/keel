import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { AgentRun } from 'api-types'
import { describe, expect, it, vi } from 'vitest'
import { TraceDrawer } from './trace-drawer'

const run: AgentRun = {
  id: 1,
  conversation_id: 'c1',
  person_id: 1,
  message: 'Can I expense a €1,200 flight to RubyConf?',
  status: 'completed',
  final_text: 'Yes, with Tunde’s approval.',
  total_tokens: 2070,
  error_message: null,
  cost_usd: null,
  feedback: null,
  feedback_reason: null,
  created_at: '2026-10-02T10:00:00Z',
  steps: [
    {
      id: 11,
      position: 1,
      kind: 'llm',
      tool_name: null,
      input: null,
      output: { content: '', tool_calls: [{ name: 'check_policy', arguments: {} }] },
      latency_ms: 900,
      tokens: 940,
    },
    {
      id: 12,
      position: 2,
      kind: 'tool',
      tool_name: 'check_policy',
      input: { request_kind: 'expense', payload: { amount_eur: 1200 } },
      output: { decision: 'require_approval' },
      latency_ms: 14,
      tokens: null,
    },
    { id: 13, position: 3, kind: 'llm', tool_name: null, input: null, output: { content: 'Yes' }, latency_ms: 1186, tokens: 1130 },
  ],
}

describe('TraceDrawer', () => {
  it('lists every model and tool step with latency, tokens and a totals footer', () => {
    render(<TraceDrawer run={run} onClose={() => {}} />)

    const steps = within(screen.getByRole('dialog', { name: 'Agent trace' })).getAllByRole('listitem')
    expect(steps).toHaveLength(3)
    expect(steps[0]).toHaveTextContent('Model → check_policy')
    expect(steps[0]).toHaveTextContent('940 tokens')
    expect(steps[1]).toHaveTextContent('check_policy')
    expect(steps[1]).toHaveTextContent('14 ms')
    expect(steps[2]).toHaveTextContent('Model answer')
    expect(screen.getByText('3 steps · 2.1 s · 2,070 tokens')).toBeInTheDocument()
  })

  it('adds what the run cost to the footer, when it is known', () => {
    render(<TraceDrawer run={{ ...run, cost_usd: 0.006123 }} onClose={() => {}} />)

    expect(screen.getByText('3 steps · 2.1 s · 2,070 tokens · $0.006')).toBeInTheDocument()
  })

  it('shows a cost too small to round as "<$0.001", not "$0.000"', () => {
    render(<TraceDrawer run={{ ...run, cost_usd: 0.0002 }} onClose={() => {}} />)

    expect(screen.getByText('3 steps · 2.1 s · 2,070 tokens · <$0.001')).toBeInTheDocument()
  })

  it("reveals a tool call's input and output as JSON on demand", async () => {
    const user = userEvent.setup()
    render(<TraceDrawer run={run} onClose={() => {}} />)

    const toolStep = within(screen.getByRole('dialog')).getAllByRole('listitem')[1]
    await user.click(within(toolStep).getByText('Input'))

    expect(within(toolStep).getByText(/"amount_eur": 1200/)).toBeVisible()
  })

  it('closes', async () => {
    const onClose = vi.fn()
    render(<TraceDrawer run={run} onClose={onClose} />)

    await userEvent.setup().click(screen.getByRole('button', { name: 'Close trace' }))

    expect(onClose).toHaveBeenCalled()
  })

  it('can be titled for something other than an agent run, such as an MCP call', () => {
    render(<TraceDrawer run={run} title="MCP call" onClose={() => {}} />)

    expect(screen.getByRole('dialog', { name: 'MCP call' })).toBeInTheDocument()
    expect(screen.queryByRole('dialog', { name: 'Agent trace' })).not.toBeInTheDocument()
  })
})
