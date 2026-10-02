module Assemble
  # Rewrites the rules of an active policy from a plain-English instruction
  # ("Raise the auto-approve limit to €800") for the agent's
  # propose_rule_change tool (SPEC.md section 9). Like PolicyExtractor, the
  # model only produces schema-validated rule data (the policy-rules
  # schema's field/operator whitelist applies) — it can rewrite a rule the
  # policy already has but not invent a new one, whose handbook source it
  # couldn't cite (AGENTS.md rule 3). The caller backtests the result and a
  # human decides; nothing is saved here.
  class RuleRecompiler
    class UnknownRule < StandardError; end

    # Returns { rule key => Rules::RuleDefinition } for the rules that
    # actually changed.
    def self.call(policy:, instruction:)
      current = policy.rules.where(status: "active").index_by(&:key)
      schema = Llm::SchemaRegistry.fetch("policy-rules")
      data = Llm::StructuredAsk.call(chat: RubyLLM.chat.with_schema(schema), schema: schema, prompt: prompt(current.values, instruction))

      data.fetch("rules").each_with_object({}) do |rule_data, changed|
        existing = current[rule_data.fetch("key")] or raise UnknownRule, "#{rule_data['key']} is not a rule of this policy"
        definition = Rules::RuleDefinition.new(
          key: existing.key, priority: rule_data.fetch("priority"),
          conditions: rule_data.fetch("conditions"), actions: rule_data.fetch("actions")
        )
        changed[existing.key] = definition unless definition == existing.to_rule_definition
      end
    end

    def self.prompt(rules, instruction)
      current = rules.map { { key: _1.key, priority: _1.priority, conditions: _1.conditions, actions: _1.actions, source_quote: _1.source_quote } }

      <<~PROMPT
        Here are the current rules of a company policy, as JSON:

        #{current.to_json}

        Apply this change request: #{instruction}

        Return only the rules that must change, each with the same key as the existing rule,
        its full new conditions and actions, and its original source_quote copied unchanged.
        Do not add rules with new keys, and do not return rules that stay the same. Keep
        ambiguities as an empty list.
      PROMPT
    end
    private_class_method :prompt
  end
end
