module Impact
  # Replays historical requests against the old and new rule set for a
  # policy proposal and reports which decisions flip (SPEC.md section 10).
  # Numbers only — the plain-English sentence is a template filled in from
  # this report, not an LLM.
  class Backtester
    FlippedDecision = Data.define(:request, :before, :after)
    Report = Data.define(:total, :flipped)

    def self.call(engine:, requests:, before_rules:, after_rules:)
      flipped = requests.filter_map do |request|
        before = engine.evaluate(request, before_rules)
        after = engine.evaluate(request, after_rules)
        next if before.outcome == after.outcome

        FlippedDecision.new(request, before, after)
      end

      Report.new(total: requests.size, flipped: flipped)
    end
  end
end
