module Impact
  # The rule-proposal counterpart of OrgImpact (SPEC.md section 10): replays
  # every past request of the policy's kind through Rules::Engine against the
  # policy's current active rules and against the same rules with
  # `after_rules` swapped in (key => RuleDefinition), via Impact::Backtester.
  # Returns the JSON stored on a ChangeProposal. The numbers are computed;
  # the sentence is a template — no LLM involved.
  class RuleImpact
    OUTCOME_PHRASES = {
      "auto_approve" => "auto-approved", "require_approval" => "sent for approval",
      "reject" => "rejected", "blocked" => "blocked"
    }.freeze

    def self.call(company:, policy:, after_rules:)
      before_rules = policy.rules.where(status: "active").map(&:to_rule_definition)
      after = before_rules.map { after_rules.fetch(_1.key, _1) }
      requests = company.requests.where(kind: policy.category).order(:id).to_a
      inputs = requests.map { Rules::RequestInput.new(requester_id: _1.requester_id, payload: _1.payload) }

      report = Backtester.call(
        engine: Rules::Engine.new(Org::GraphSnapshot.load(company)),
        requests: inputs, before_rules: before_rules, after_rules: after
      )
      by_input = inputs.zip(requests).to_h.compare_by_identity
      conflicts = new_conflicts(before_rules, after)

      { "backtest" => {
        "kind" => policy.category, "total" => report.total, "flipped_count" => report.flipped.size,
        "flipped" => report.flipped.map { serialize(_1, by_input) },
        "new_conflicts" => conflicts,
        "summary" => summary(policy.category, report)
      } }
    end

    def self.serialize(flip, by_input)
      request = by_input[flip.request]
      {
        "request_id" => request&.id, "requester_id" => flip.request.requester_id, "payload" => flip.request.payload,
        "before" => flip.before.outcome, "after" => flip.after.outcome
      }
    end
    private_class_method :serialize

    # Same-priority overlaps the rewrite introduces (SPEC.md section 7's
    # conflict detection, on the proposed rule set): they disagree on the
    # same request, and the engine's tie-break then silently picks one.
    def self.new_conflicts(before_rules, after_rules)
      existing = Rules::ConflictDetector.call(before_rules).to_set { [ _1.rule_a_key, _1.rule_b_key ].sort }

      Rules::ConflictDetector.call(after_rules).filter_map do |conflict|
        pair = [ conflict.rule_a_key, conflict.rule_b_key ].sort
        next if existing.include?(pair)

        example = conflict.probes.first
        { "rules" => pair, "example" => example, "warning" => warning(pair, example) }
      end
    end
    private_class_method :new_conflicts

    def self.warning(rules, example)
      "#{rules.join(' overlaps with ')} at the same priority, so they disagree on requests such as " \
        "#{example.map { |field, value| "#{field.split('.').last}=#{value}" }.join(', ')} and the more restrictive one wins."
    end
    private_class_method :warning

    def self.summary(kind, report)
      return "This would not have changed any of the #{report.total} past #{kind} decisions." if report.flipped.empty?

      moves = report.flipped.group_by { [ _1.before.outcome, _1.after.outcome ] }.map do |(before, after), flips|
        "#{flips.size} would have been #{phrase(after)} instead of #{phrase(before)}"
      end
      "This would have changed #{report.flipped.size} of #{report.total} past #{kind} decisions: #{moves.join('; ')}."
    end
    private_class_method :summary

    def self.phrase(outcome) = OUTCOME_PHRASES.fetch(outcome, outcome)
    private_class_method :phrase
  end
end
