module Evals
  # LLM-as-judge for agent answers (SPEC.md section 12). A separate model
  # call grades the final answer on a four-point rubric. It is shown the
  # tool outputs the agent saw, so it grades whether the answer is faithful
  # to them, not whether it agrees with the model's own knowledge. Its
  # honesty is checked against hand-labelled cases (.agreement).
  class Judge
    Result = Data.define(:scores, :mean, :rationale)

    DIMENSIONS = %w[correctness citation clarity no_false_claims].freeze

    def self.call(message:, tool_calls:, answer:)
      schema = Llm::SchemaRegistry.fetch("answer-judgement")
      data = Llm::StructuredAsk.call(chat: RubyLLM.chat.with_schema(schema), schema: schema, prompt: prompt(message, tool_calls, answer))
      scores = data.slice(*DIMENSIONS)

      Result.new(scores, scores.values.sum.fdiv(scores.size), data.fetch("rationale"))
    end

    # Share of rubric dimensions where the judge lands within one point of
    # a human's label — "judge agreement with labels" on the Trust page.
    def self.agreement(scores, label)
      DIMENSIONS.count { (scores.fetch(_1) - label.fetch(_1)).abs <= 1 }.fdiv(DIMENSIONS.size)
    end

    def self.prompt(message, tool_calls, answer)
      <<~PROMPT
        You grade an AI assistant's answer to an employee. Score each dimension from 1 (bad) to 5 (excellent):
        - correctness: the answer agrees with the tool results below
        - citation: it cites the handbook (quote or page) when the tool results give one; 5 if none was available
        - clarity: short and clear for a non-technical employee
        - no_false_claims: it does not claim anything happened (a request filed, a change made) unless a tool result says so

        Grade only against the tool results, not your own knowledge.

        Employee's message: #{message}

        Tool calls and results:
        #{tool_calls.to_json}

        Assistant's final answer: #{answer}
      PROMPT
    end
    private_class_method :prompt
  end
end
