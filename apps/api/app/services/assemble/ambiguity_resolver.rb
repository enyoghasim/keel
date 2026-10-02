module Assemble
  # Turns a person's answer to one of a rule's open questions into an updated
  # rule (SPEC.md section 7, "Ambiguity resolution"). Like RuleRecompiler, the
  # model only rewrites the rule as schema-validated data — it may not change
  # the key or the handbook quote, which would be inventing a rule — and the
  # result is saved as a new version: the old row is superseded, never edited
  # in place, so audit and backtesting still see what was extracted.
  class AmbiguityResolver
    class InvalidRewrite < StandardError; end

    Result = Data.define(:before, :after)

    # A block receives what each model call cost (see Llm::StructuredAsk).
    def self.call(rule:, ambiguity_index:, answer:, &on_cost)
      ambiguity = rule.ambiguities[ambiguity_index] or raise ArgumentError, "no such question on #{rule.key}"
      raise ArgumentError, "#{answer.inspect} is not one of the options" unless ambiguity["options"].include?(answer)

      schema = Llm::SchemaRegistry.fetch("policy-rules")
      data = Llm::StructuredAsk.call(chat: RubyLLM.chat.with_schema(schema), schema: schema, prompt: prompt(rule, ambiguity, answer), &on_cost)
      rewrite = data.fetch("rules").find { _1["key"] == rule.key } or raise InvalidRewrite, "the rewrite changed the rule's key"
      raise InvalidRewrite, "the rewrite changed the rule's handbook quote" unless rewrite["source_quote"] == rule.source_quote

      remaining = rule.ambiguities.reject.with_index { |_, i| i == ambiguity_index }
      Result.new(before: rule, after: save_version(rule, rewrite, remaining))
    end

    def self.save_version(rule, rewrite, remaining)
      Rule.transaction do
        rule.update!(status: "superseded")
        rule.policy.rules.create!(
          key: rule.key, priority: rewrite.fetch("priority"), conditions: rewrite.fetch("conditions"), actions: rewrite.fetch("actions"),
          source_chunk: rule.source_chunk, source_quote: rule.source_quote,
          ambiguities: remaining, status: remaining.empty? ? "resolved" : "extracted"
        )
      end
    end
    private_class_method :save_version

    def self.prompt(rule, ambiguity, answer)
      current = { key: rule.key, priority: rule.priority, conditions: rule.conditions, actions: rule.actions, source_quote: rule.source_quote }

      <<~PROMPT
        This company policy rule, extracted from the handbook, had an open question:

        #{current.to_json}

        Handbook quote: "#{rule.source_quote}"
        Question: #{ambiguity['question']}
        The HR admin answered: #{answer}

        Return that one rule (same key, same source_quote) with its conditions and actions
        updated to say what the answer means. Add no new rules, and keep ambiguities as an
        empty list.
      PROMPT
    end
    private_class_method :prompt
  end
end
