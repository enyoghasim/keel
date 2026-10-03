import { createConsumer } from '@rails/actioncable'
import { act, render, waitFor } from '@testing-library/react'
import { StrictMode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { useCableHealthy as UseCableHealthy, useChannel as UseChannel } from './cable'

vi.mock('@rails/actioncable', () => ({
  createConsumer: vi.fn(() => ({
    subscriptions: { create: vi.fn(() => ({ unsubscribe: vi.fn() })) },
  })),
}))

// cable.ts creates its ActionCable consumer once, as a module-level
// singleton, at import time. vi.resetModules() + a fresh dynamic import per
// test is what gives each test its own singleton to make assertions about —
// reusing one import across tests would mean only the first test ever
// observes a createConsumer call (the rest just reuse the memoized consumer).
async function importFreshUseChannel(): Promise<typeof UseChannel> {
  vi.resetModules()
  return (await import('./cable')).useChannel
}

async function importFreshCable(): Promise<{ useChannel: typeof UseChannel; useCableHealthy: typeof UseCableHealthy }> {
  vi.resetModules()
  const mod = await import('./cable')
  return { useChannel: mod.useChannel, useCableHealthy: mod.useCableHealthy }
}

function Harness({ useChannel, onEvent }: { useChannel: typeof UseChannel; onEvent: (event: unknown) => void }) {
  useChannel('AssembleChannel', { company_id: '1' }, onEvent)
  return null
}

describe('useChannel', () => {
  beforeEach(() => {
    vi.mocked(createConsumer).mockClear()
  })

  it('creates exactly one consumer even when several components subscribe', async () => {
    const useChannel = await importFreshUseChannel()
    render(<Harness useChannel={useChannel} onEvent={vi.fn()} />)
    render(<Harness useChannel={useChannel} onEvent={vi.fn()} />)

    expect(vi.mocked(createConsumer)).toHaveBeenCalledTimes(1)
  })

  it('subscribes to the given channel with its params', async () => {
    const useChannel = await importFreshUseChannel()
    render(<Harness useChannel={useChannel} onEvent={vi.fn()} />)

    const subscriptionsCreate = vi.mocked(createConsumer).mock.results[0]!.value.subscriptions.create
    expect(subscriptionsCreate).toHaveBeenCalledWith(
      { channel: 'AssembleChannel', company_id: '1' },
      expect.objectContaining({ received: expect.any(Function) }),
    )
  })

  it('forwards received events to onEvent', async () => {
    const useChannel = await importFreshUseChannel()
    const onEvent = vi.fn()
    render(<Harness useChannel={useChannel} onEvent={onEvent} />)

    const subscriptionsCreate = vi.mocked(createConsumer).mock.results[0]!.value.subscriptions.create
    const mixin = subscriptionsCreate.mock.calls[0][1]
    const event = { stage: 'csv', event: 'mapping_complete', data: {}, progress: 0.1 }
    mixin.received(event)

    expect(onEvent).toHaveBeenCalledWith(event)
  })

  it('unsubscribes once the last component using a channel unmounts', async () => {
    const unsubscribe = vi.fn()
    vi.mocked(createConsumer).mockReturnValueOnce({
      subscriptions: { create: vi.fn(() => ({ unsubscribe })) },
    } as unknown as ReturnType<typeof createConsumer>)
    const useChannel = await importFreshUseChannel()

    const { unmount } = render(<Harness useChannel={useChannel} onEvent={vi.fn()} />)
    unmount()

    await waitFor(() => expect(unsubscribe).toHaveBeenCalledTimes(1))
  })

  // React StrictMode mounts, unmounts and remounts every effect in dev. An
  // unsubscribe and resubscribe for the same identifier that close together
  // race on the server, which can leave nothing streaming — so a remount
  // reuses the live subscription instead.
  it('keeps one live subscription through a StrictMode remount', async () => {
    const useChannel = await importFreshUseChannel()
    const onEvent = vi.fn()
    render(
      <StrictMode>
        <Harness useChannel={useChannel} onEvent={onEvent} />
      </StrictMode>,
    )

    const { create } = vi.mocked(createConsumer).mock.results[0]!.value.subscriptions
    await new Promise((resolve) => setTimeout(resolve, 50))
    expect(create).toHaveBeenCalledTimes(1)
    expect(create.mock.results[0].value.unsubscribe).not.toHaveBeenCalled()

    create.mock.calls[0][1].received({ event: 'run' })
    expect(onEvent).toHaveBeenCalledTimes(1)
  })

  it('shares one subscription between components on the same channel, delivering to each', async () => {
    const useChannel = await importFreshUseChannel()
    const first = vi.fn()
    const second = vi.fn()
    render(<Harness useChannel={useChannel} onEvent={first} />)
    const { unmount } = render(<Harness useChannel={useChannel} onEvent={second} />)

    const { create } = vi.mocked(createConsumer).mock.results[0]!.value.subscriptions
    expect(create).toHaveBeenCalledTimes(1)
    create.mock.calls[0][1].received({ n: 1 })
    expect(first).toHaveBeenCalledWith({ n: 1 })
    expect(second).toHaveBeenCalledWith({ n: 1 })

    unmount()
    create.mock.calls[0][1].received({ n: 2 })
    expect(first).toHaveBeenCalledWith({ n: 2 })
    expect(second).not.toHaveBeenCalledWith({ n: 2 })
  })

  it('calls onConnected each time the subscription connects, and at once when it already has', async () => {
    const useChannel = await importFreshUseChannel()
    const first = vi.fn()
    function Connected({ onConnected }: { onConnected: () => void }) {
      useChannel('AssembleChannel', { company_id: '1' }, vi.fn(), onConnected)
      return null
    }
    render(<Connected onConnected={first} />)

    const subscriptionsCreate = vi.mocked(createConsumer).mock.results[0]!.value.subscriptions.create
    const mixin = subscriptionsCreate.mock.calls[0][1]
    expect(first).not.toHaveBeenCalled()

    mixin.connected()
    expect(first).toHaveBeenCalledTimes(1)
    mixin.connected() // a reconnect after a dropped socket
    expect(first).toHaveBeenCalledTimes(2)

    const late = vi.fn()
    render(<Connected onConnected={late} />)
    expect(late).toHaveBeenCalledTimes(1)
  })
})

// Every live page falls back to polling its REST endpoint off this signal
// once the socket looks unreachable — a tunnel that only proxies plain
// HTTP, for instance, where ActionCable's own reconnect loop retries
// forever without a subscription ever confirming "connected".
describe('useCableHealthy', () => {
  beforeEach(() => {
    vi.mocked(createConsumer).mockClear()
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  function HealthHarness({ useCableHealthy }: { useCableHealthy: typeof UseCableHealthy }) {
    const healthy = useCableHealthy()
    return <div data-testid="healthy">{String(healthy)}</div>
  }

  it('starts healthy, optimistically', async () => {
    const { useCableHealthy } = await importFreshCable()
    const { getByTestId } = render(<HealthHarness useCableHealthy={useCableHealthy} />)

    expect(getByTestId('healthy').textContent).toBe('true')
  })

  it('goes unhealthy if nothing connects within the grace period', async () => {
    const { useCableHealthy } = await importFreshCable()
    const { getByTestId } = render(<HealthHarness useCableHealthy={useCableHealthy} />)

    await act(() => vi.advanceTimersByTimeAsync(5000))

    expect(getByTestId('healthy').textContent).toBe('false')
  })

  it('stays healthy once a subscription connects before the grace period elapses', async () => {
    const { useChannel, useCableHealthy } = await importFreshCable()
    function Harness() {
      useChannel('AssembleChannel', { company_id: '1' }, vi.fn())
      return <HealthHarness useCableHealthy={useCableHealthy} />
    }
    const { getByTestId } = render(<Harness />)
    const mixin = vi.mocked(createConsumer).mock.results[0]!.value.subscriptions.create.mock.calls[0][1]

    act(() => mixin.connected())
    await act(() => vi.advanceTimersByTimeAsync(5000))

    expect(getByTestId('healthy').textContent).toBe('true')
  })

  it('goes unhealthy again after a connected subscription drops and nothing reconnects', async () => {
    const { useChannel, useCableHealthy } = await importFreshCable()
    function Harness() {
      useChannel('AssembleChannel', { company_id: '1' }, vi.fn())
      return <HealthHarness useCableHealthy={useCableHealthy} />
    }
    const { getByTestId } = render(<Harness />)
    const mixin = vi.mocked(createConsumer).mock.results[0]!.value.subscriptions.create.mock.calls[0][1]

    act(() => mixin.connected())
    expect(getByTestId('healthy').textContent).toBe('true')

    act(() => mixin.disconnected())
    await act(() => vi.advanceTimersByTimeAsync(5000))

    expect(getByTestId('healthy').textContent).toBe('false')
  })
})
