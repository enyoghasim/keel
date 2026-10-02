import { createConsumer } from '@rails/actioncable'
import { useEffect } from 'react'

const consumer = createConsumer('/cable')

export function useChannel<T>(channel: string, params: object, onEvent: (event: T) => void) {
  const paramsKey = JSON.stringify(params)

  useEffect(() => {
    const subscription = consumer.subscriptions.create({ channel, ...params }, { received: onEvent })
    return () => {
      subscription.unsubscribe()
    }
  }, [channel, paramsKey, onEvent])
}
