import { useEffect } from 'react'

export function useChannel<T>(
  channel: string,
  params: object,
  onEvent: (event: T) => void,
) {
  const paramsKey = JSON.stringify(params)

  useEffect(() => {
    // TODO: wire up an actual Action Cable consumer once apps/api exposes channels.
    // const sub = consumer.subscriptions.create({ channel, ...params }, { received: onEvent })
    // return () => sub.unsubscribe()
  }, [channel, paramsKey, onEvent])
}
