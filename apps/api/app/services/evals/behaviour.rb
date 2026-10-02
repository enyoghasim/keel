module Evals
  # Scores rules by behaviour, not text (SPEC.md section 12). Both rule sets
  # are run through the engine's own selection logic (Rules::Engine.decide)
  # on the same probe contexts — boundary values and categories taken from
  # Rules::ConflictDetector — and compared by decision and approver
  # references. Two differently written rule sets that behave alike score
  # 100%; one wrong operator disagrees on exactly the probe it affects.
  module Behaviour
    Comparison = Data.define(:score, :probe_count, :disagreements)

    def self.compare(expected_rules, actual_rules)
      probes = probes_for([ expected_rules, actual_rules ])
      disagreements = probes.filter_map do |probe|
        want, got = decide(probe, expected_rules), decide(probe, actual_rules)
        { "probe" => probe, "expected" => label(want), "actual" => label(got) } unless want == got
      end

      Comparison.new((probes.size - disagreements.size).fdiv(probes.size), probes.size, disagreements)
    end

    # Mean pairwise agreement across several outputs of the same input —
    # compile stability. 1.0 means every output behaves identically.
    def self.agreement(rule_sets)
      return 1.0 if rule_sets.size < 2

      probes = probes_for(rule_sets)
      decisions = rule_sets.map { |rules| probes.map { decide(_1, rules) } }
      pairs = decisions.combination(2).map { |a, b| a.zip(b).count { _1 == _2 }.fdiv(probes.size) }
      pairs.sum / pairs.size
    end

    def self.probes_for(rule_sets)
      probes = Rules::ConflictDetector.probe_contexts(rule_sets.flatten)
      probes.empty? ? [ {} ] : probes
    end
    private_class_method :probes_for

    # [decision, approver references]; a probe a rule set can't evaluate
    # (e.g. an operator applied to a value of the wrong type) is its own outcome.
    def self.decide(probe, rules)
      action = Rules::Engine.decide(probe, rules).action
      [ action["decision"], Array(action["approvers"]).sort ]
    rescue ArgumentError, NoMethodError, TypeError
      [ "error", [] ]
    end
    private_class_method :decide

    def self.label(outcome)
      decision, approvers = outcome
      approvers.empty? ? decision : "#{decision} (#{approvers.join(', ')})"
    end
    private_class_method :label
  end
end
