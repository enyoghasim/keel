import { createConsumer } from '@rails/actioncable'
import { useEffect } from 'react'

const consumer = createConsumer('/cable')

// How long a subscription nobody is listening to stays open before it's
// really unsubscribed — long enough to span a React StrictMode remount.
const UNSUBSCRIBE_DELAY_MS = 25

interface SharedSubscription {
  subscription: { unsubscribe: () => void }
  listeners: Set<(event: unknown) => void>
  pendingUnsubscribe?: ReturnType<typeof setTimeout>
}

// One Action Cable subscription per channel+params identifier, shared by
// every component listening to it. Unsubscribing and resubscribing the same
// identifier in quick succession (StrictMode's mount/unmount/remount, or a
// drawer opening on a run the command bar already follows) races on the
// server and can leave nothing streaming, so the last listener leaving only
// schedules the unsubscribe, and a listener arriving in time cancels it.
const shared = new Map<string, SharedSubscription>()

function subscribe(channel: string, params: object, listener: (event: unknown) => void) {
  const key = JSON.stringify({ channel, ...params })
  let entry = shared.get(key)

  if (!entry) {
    const listeners = new Set<(event: unknown) => void>()
    const subscription = consumer.subscriptions.create(
      { channel, ...params },
      { received: (event: unknown) => listeners.forEach((l) => l(event)) },
    )
    entry = { subscription, listeners }
    shared.set(key, entry)
  }

  clearTimeout(entry.pendingUnsubscribe)
  entry.listeners.add(listener)

  return () => {
    const current = shared.get(key)
    if (!current) return
    current.listeners.delete(listener)
    if (current.listeners.size > 0) return

    current.pendingUnsubscribe = setTimeout(() => {
      if (current.listeners.size > 0) return
      current.subscription.unsubscribe()
      shared.delete(key)
    }, UNSUBSCRIBE_DELAY_MS)
  }
}

export function useChannel<T>(channel: string, params: object, onEvent: (event: T) => void) {
  const paramsKey = JSON.stringify(params)

  useEffect(
    () => subscribe(channel, JSON.parse(paramsKey) as object, onEvent as (event: unknown) => void),
    [channel, paramsKey, onEvent],
  )
}
