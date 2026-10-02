module Evals
  # Scores one policy_extraction eval case (SPEC.md section 12) — no LLM.
  # Three checks on the rules the model compiled from a passage:
  #   * behaviour: do they decide probe requests like the expected rules
  #     (Evals::Behaviour)? The headline score.
  #   * quotes: is every rule's source_quote verbatim in the passage?
  #   * ambiguity recall: did it flag the vague phrases the case expects?
  # A case passes only when all three are perfect.
  class PolicyExtractionScorer
    Result = Data.define(:passed, :score, :metrics, :diff)

    def self.call(expected:, actual_rules:, passage:)
      expected_rules = expected.fetch("rules").map { rule_definition(_1) }
      actual_definitions = actual_rules.map { rule_definition(_1) }

      comparison = Behaviour.compare(expected_rules, actual_definitions)
      quote_failures = actual_rules.reject { passage.include?(_1["source_quote"].to_s) }
      missed = missed_ambiguities(expected["ambiguities"], actual_rules)

      metrics = {
        "behaviour" => comparison.score,
        "quotes_verified" => actual_rules.empty? ? 1.0 : (actual_rules.size - quote_failures.size).fdiv(actual_rules.size),
        "ambiguity_recall" => recall(expected["ambiguities"], missed),
        "probes" => comparison.probe_count
      }.compact

      diff = comparison.disagreements.map { { "field" => "behaviour" }.merge(_1) } +
             quote_failures.map { { "field" => "source_quote", "rule" => _1["key"], "actual" => _1["source_quote"] } } +
             missed.map { { "field" => "ambiguity", "expected" => _1 } }

      Result.new(diff.empty?, comparison.score, metrics, diff)
    end

    def self.rule_definition(rule)
      Rules::RuleDefinition.new(key: rule["key"], priority: rule["priority"], conditions: rule["conditions"], actions: rule["actions"])
    end

    def self.missed_ambiguities(expected_phrases, actual_rules)
      found = actual_rules.flat_map { _1["ambiguities"] || [] }.map { _1["phrase"].to_s.downcase }
      Array(expected_phrases).reject do |phrase|
        phrase = phrase.downcase
        found.any? { _1.include?(phrase) || phrase.include?(_1) }
      end
    end
    private_class_method :missed_ambiguities

    def self.recall(expected_phrases, missed)
      return nil if expected_phrases.blank?

      (expected_phrases.size - missed.size).fdiv(expected_phrases.size)
    end
    private_class_method :recall
  end
end
