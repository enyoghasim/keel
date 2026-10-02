module Rules
  # Finds pairs of same-priority rules that disagree on the same request,
  # with no LLM involved (SPEC.md section 7). For each pair, it probes every
  # boundary value around the numeric thresholds either rule mentions,
  # crossed with every categorical value (department, category, ...) either
  # rule mentions, and checks whether both match with different actions.
  class ConflictDetector
    Conflict = Data.define(:rule_a_key, :rule_b_key, :probes)

    def self.call(rules)
      rules.combination(2).each_with_object([]) do |(rule_a, rule_b), conflicts|
        next unless rule_a.priority == rule_b.priority
        next if rule_a.actions == rule_b.actions

        matches = probes(rule_a, rule_b).select do |probe|
          Condition.match?(rule_a.conditions, probe) && Condition.match?(rule_b.conditions, probe)
        end

        conflicts << Conflict.new(rule_a.key, rule_b.key, matches) if matches.any?
      end
    end

    def self.probes(rule_a, rule_b)
      fields = candidates_by_field(rule_a.conditions).merge(candidates_by_field(rule_b.conditions)) { |_, a, b| a | b }
      return [] if fields.empty?

      keys = fields.keys
      value_sets = fields.values
      value_sets[0].product(*value_sets[1..]).map { |combo| keys.zip(combo).to_h }
    end
    private_class_method :probes

    def self.candidates_by_field(node)
      leaves(node).each_with_object(Hash.new { |h, k| h[k] = [] }) do |leaf, acc|
        acc[leaf["field"]].concat(candidate_values(leaf["value"])).uniq!
      end
    end
    private_class_method :candidates_by_field

    def self.leaves(node)
      return node["all"].flat_map { leaves(_1) } if node["all"]
      return node["any"].flat_map { leaves(_1) } if node["any"]

      [ node ]
    end
    private_class_method :leaves

    # Numeric values become their own boundary ± 1 (the "499, 500, 501"
    # probing SPEC.md describes); non-numeric values are probed as-is.
    def self.candidate_values(value)
      Array(value).flat_map { |v| v.is_a?(Numeric) ? [ v - 1, v, v + 1 ] : [ v ] }
    end
    private_class_method :candidate_values
  end
end
