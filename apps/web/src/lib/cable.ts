import { createConsumer } from '@rails/actioncable'
import { useEffect, useSyncExternalStore } from 'react'

const consumer = createConsumer('/cable')

// How long a subscription nobody is listening to stays open before it's
// really unsubscribed — long enough to span a React StrictMode remount.
const UNSUBSCRIBE_DELAY_MS = 25

// How long we wait for ANY subscription to confirm "connected" before
// treating the socket as unreachable — not every proxy forwards a
// WebSocket upgrade (a plain-HTTP-only tunnel, say), and ActionCable's own
// reconnection loop retries forever without ever surfacing that to this
// app. Generous enough that ordinary network latency never trips it, only
// a connection that's genuinely blocked or absent. Every live page polls
// its REST endpoint instead while this is false — see useCableHealthy.
const UNHEALTHY_TIMEOUT_MS = 5000
export const CABLE_POLL_INTERVAL_MS = 3000

let healthy = true
let unhealthyTimer: ReturnType<typeof setTimeout> | undefined
const healthListeners = new Set<() => void>()

function setHealthy(next: boolean) {
  if (healthy === next) return
  healthy = next
  healthListeners.forEach((listener) => listener())
}

function noteConnected() {
  clearTimeout(unhealthyTimer)
  unhealthyTimer = undefined
  setHealthy(true)
}

// Only the first call starts the clock — a second subscription dropping
// while we're already counting down from the first shouldn't push the
// deadline back out.
function noteNotConnected() {
  if (unhealthyTimer) return
  unhealthyTimer = setTimeout(() => setHealthy(false), UNHEALTHY_TIMEOUT_MS)
}

// Nothing has had the chance to connect yet at module load (page just
// opened) — start the same countdown immediately rather than waiting on a
// "disconnected" event a socket that never opened will never send.
noteNotConnected()

/**
 * False once no subscription has confirmed a connection within
 * UNHEALTHY_TIMEOUT_MS — true again the moment any subscription does. A
 * live page pairs this with its existing REST useQuery's refetchInterval
 * (CABLE_POLL_INTERVAL_MS while unhealthy, false once the socket's back)
 * instead of running a second, parallel fetch path.
 */
export function useCableHealthy(): boolean {
  return useSyncExternalStore(
    (listener) => {
      healthListeners.add(listener)
      return () => healthListeners.delete(listener)
    },
    () => healthy,
  )
}

interface SharedSubscription {
  subscription: { unsubscribe: () => void }
  listeners: Set<(event: unknown) => void>
  connectedListeners: Set<() => void>
  connected: boolean
  pendingUnsubscribe?: ReturnType<typeof setTimeout>
}

// One Action Cable subscription per channel+params identifier, shared by
// every component listening to it. Unsubscribing and resubscribing the same
// identifier in quick succession (StrictMode's mount/unmount/remount, or a
// drawer opening on a run the command bar already follows) races on the
// server and can leave nothing streaming, so the last listener leaving only
// schedules the unsubscribe, and a listener arriving in time cancels it.
const shared = new Map<string, SharedSubscription>()

function subscribe(
  channel: string,
  params: object,
  listener: (event: unknown) => void,
  onConnected?: () => void,
) {
  const key = JSON.stringify({ channel, ...params })
  let entry = shared.get(key)

  if (!entry) {
    const listeners = new Set<(event: unknown) => void>()
    const connectedListeners = new Set<() => void>()
    const created: SharedSubscription = {
      subscription: consumer.subscriptions.create(
        { channel, ...params },
        {
          received: (event: unknown) => listeners.forEach((l) => l(event)),
          connected: () => {
            created.connected = true
            noteConnected()
            connectedListeners.forEach((l) => l())
          },
          disconnected: () => {
            created.connected = false
            noteNotConnected()
          },
        },
      ),
      listeners,
      connectedListeners,
      connected: false,
    }
    entry = created
    shared.set(key, entry)
  }

  clearTimeout(entry.pendingUnsubscribe)
  entry.listeners.add(listener)
  if (onConnected) {
    entry.connectedListeners.add(onConnected)
    if (entry.connected) onConnected()
  }

  return () => {
    const current = shared.get(key)
    if (!current) return
    current.listeners.delete(listener)
    if (onConnected) current.connectedListeners.delete(onConnected)
    if (current.listeners.size > 0) return

    current.pendingUnsubscribe = setTimeout(() => {
      if (current.listeners.size > 0) return
      current.subscription.unsubscribe()
      shared.delete(key)
    }, UNSUBSCRIBE_DELAY_MS)
  }
}

/**
 * `onConnected` runs whenever the subscription is confirmed (and straight
 * away if it already is), so a page can fetch what it missed before it
 * subscribed and again after a dropped socket reconnects.
 */
export function useChannel<T>(channel: string, params: object, onEvent: (event: T) => void, onConnected?: () => void) {
  const paramsKey = JSON.stringify(params)

  useEffect(
    () => subscribe(channel, JSON.parse(paramsKey) as object, onEvent as (event: unknown) => void, onConnected),
    [channel, paramsKey, onEvent, onConnected],
  )
}
