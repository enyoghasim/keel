import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

export function QuestionBox({ onAsk, asking }: { onAsk: (question: string) => void; asking: boolean }) {
  const [question, setQuestion] = useState('')

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault()
        if (question.trim() !== '') onAsk(question.trim())
      }}
      className="flex gap-2"
    >
      <label htmlFor="insight-question" className="sr-only">
        Ask a question
      </label>
      <Input
        id="insight-question"
        type="text"
        value={question}
        onChange={(e) => setQuestion(e.target.value)}
        placeholder="e.g. Which teams took the most leave last quarter?"
        className="h-9 text-[14px]"
      />
      <Button type="submit" disabled={question.trim() === '' || asking} className="h-9 shrink-0 px-4">
        {asking ? 'Asking…' : 'Ask'}
      </Button>
    </form>
  )
}
