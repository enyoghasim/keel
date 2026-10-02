import { describe, expect, it } from 'vitest'
import { type AssembleEvent, mergeEvents } from './assemble-event'

const event = (seq: number | undefined, name = 'Ada'): AssembleEvent => ({
  seq,
  stage: 'graph',
  event: 'person_added',
  data: { name },
  progress: 0.2,
})

describe('mergeEvents', () => {
  it('keeps an event that is both in the stored log and arrived live only once', () => {
    expect(mergeEvents([event(0), event(1)], [event(1), event(2)]).map((e) => e.seq)).toEqual([0, 1, 2])
  })

  it('puts events in log order even when live ones arrived before the log did', () => {
    expect(mergeEvents([event(0), event(1)], [event(3), event(2)]).map((e) => e.seq)).toEqual([0, 1, 2, 3])
  })

  it('keeps events with no seq, after the numbered ones, in arrival order', () => {
    expect(mergeEvents([event(0)], [event(undefined, 'A'), event(undefined, 'B')]).map((e) => e.data.name ?? e.seq)).toEqual([
      'Ada',
      'A',
      'B',
    ])
  })
})
