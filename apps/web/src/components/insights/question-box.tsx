import { useState } from 'react'

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
      <input
        id="insight-question"
        type="text"
        value={question}
        onChange={(e) => setQuestion(e.target.value)}
        placeholder="e.g. Which teams took the most leave last quarter?"
        className="block w-full rounded-lg border border-border bg-card px-3.5 py-2 text-[14px] shadow-xs focus:border-ring focus:outline-none"
      />
      <button
        type="submit"
        disabled={question.trim() === '' || asking}
        className="shrink-0 rounded-lg bg-primary px-4 py-2 text-[13px] font-medium text-primary-foreground shadow-btn disabled:cursor-not-allowed disabled:opacity-40"
      >
        {asking ? 'Asking…' : 'Ask'}
      </button>
    </form>
  )
}
