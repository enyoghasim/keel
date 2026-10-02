module Rules
  # Turns Rules::ConflictDetector's findings into what the policy page shows
  # (SPEC.md section 7): a sentence, one example request, and the usual fix.
  # All deterministic — the sentence is built from the rules and the
  # suggestion is a priority bump, so there is no model to be wrong.
  class ConflictReport
    Entry = Data.define(:rule_a_key, :rule_b_key, :example, :explanation, :fix)
    Fix = Data.define(:rule_key, :new_priority)

    def self.call(rules)
      by_key = rules.index_by(&:key)

      ConflictDetector.call(rules).map do |conflict|
        a = by_key.fetch(conflict.rule_a_key)
        b = by_key.fetch(conflict.rule_b_key)
        example = conflict.probes[conflict.probes.size / 2]
        Entry.new(a.key, b.key, example, explain(a, b, example), suggest(a, b))
      end
    end

    def self.explain(a, b, example)
      sample = example.map { |field, value| "#{field.split('.').last.tr('_', ' ')} #{value}" }.join(", ")
      "Rules #{a.key} (#{phrase(a)}) and #{b.key} (#{phrase(b)}) both match requests like #{sample}, and neither outranks the other."
    end
    private_class_method :explain

    def self.phrase(rule) = Explainer::DECISION_PHRASES.fetch(rule.actions["decision"]).downcase
    private_class_method :phrase

    # The rule with more conditions is the narrower exception; it should win.
    def self.suggest(a, b)
      narrower, wider = [ a, b ].sort_by { -ConflictDetector.leaves(_1.conditions).size }
      return nil if ConflictDetector.leaves(narrower.conditions).size == ConflictDetector.leaves(wider.conditions).size

      Fix.new(rule_key: narrower.key, new_priority: wider.priority + 1)
    end
    private_class_method :suggest
  end
end
