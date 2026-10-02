import { render, screen } from '@testing-library/react'
import type { EvalRun, PromptVersion } from 'api-types'
import { describe, expect, it } from 'vitest'
import { versionAccuracyPoints } from './version-accuracy'
import { VersionAccuracyChart } from './version-accuracy-chart'

const run = (accuracy: number): EvalRun =>
  ({ id: 1, suite: 'policy_extraction', status: 'completed', accuracy, stability: null }) as EvalRun

const version = (n: number, latest: EvalRun | null): PromptVersion => ({
  id: n,
  key: 'policy_extractor',
  version: n,
  model: null,
  active: false,
  notes: null,
  created_at: '2026-10-01T00:00:00Z',
  latest_run: latest,
  regressions: [],
})

describe('versionAccuracyPoints', () => {
  it('orders one key’s versions oldest first and skips versions never evaluated', () => {
    const points = versionAccuracyPoints([version(3, run(0.9)), version(2, null), version(1, run(0.5))], 'policy_extractor')

    expect(points).toEqual([
      { label: 'v1', accuracy: 0.5 },
      { label: 'v3', accuracy: 0.9 },
    ])
  })

  it('ignores other prompt keys', () => {
    expect(versionAccuracyPoints([{ ...version(1, run(0.5)), key: 'agent_system' }], 'policy_extractor')).toEqual([])
  })
})

describe('VersionAccuracyChart', () => {
  it('renders nothing until two versions have been evaluated', () => {
    const { container } = render(<VersionAccuracyChart versions={[version(1, run(0.5))]} promptKey="policy_extractor" />)

    expect(container).toBeEmptyDOMElement()
  })

  it('shows accuracy across prompt versions once there are two to compare', () => {
    render(<VersionAccuracyChart versions={[version(2, run(0.9)), version(1, run(0.5))]} promptKey="policy_extractor" />)

    expect(screen.getByRole('figure', { name: 'Accuracy by prompt version' })).toBeInTheDocument()
  })
})
