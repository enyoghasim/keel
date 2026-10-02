require "rails_helper"

RSpec.describe Evals::Behaviour do
  # SPEC.md section 12: compiled rules are scored by what they DO on probe
  # requests, not by comparing JSON — two different rule sets can behave
  # identically, and one wrong operator disagrees on exactly one probe.
  def rule(key, conditions, actions, priority: 10)
    Rules::RuleDefinition.new(key: key, priority: priority, conditions: conditions, actions: actions)
  end

  let(:conference_conditions) do
    ->(op) { { "all" => [
      { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
      { "field" => "payload.category", "op" => "eq", "value" => "conference" },
      { "field" => "payload.amount_eur", "op" => op, "value" => 1000 }
    ] } }
  end
  let(:auto) { { "decision" => "auto_approve" } }
  let(:expected) { [ rule("conference", conference_conditions.call("lte"), auto) ] }

  describe ".compare" do
    it "scores 100% when differently written rules behave identically" do
      reordered = { "all" => conference_conditions.call("lte")["all"].reverse }
      same_behaviour = [ rule("conference_v2", reordered, auto, priority: 3) ]

      comparison = described_class.compare(expected, same_behaviour)

      expect(comparison.score).to eq(1.0)
      expect(comparison.disagreements).to eq([])
    end

    it "pins a lt-for-lte mistake on exactly the €1,000 probe" do
      mistaken = [ rule("conference", conference_conditions.call("lt"), auto) ]

      comparison = described_class.compare(expected, mistaken)

      expect(comparison.probe_count).to eq(3)
      expect(comparison.score).to be_within(0.001).of(2 / 3.0)
      expect(comparison.disagreements.size).to eq(1)
      expect(comparison.disagreements.first).to include(
        "probe" => { "requester.department" => "Engineering", "payload.category" => "conference", "payload.amount_eur" => 1000 },
        "expected" => "auto_approve", "actual" => "require_approval (manager_of(requester))"
      )
    end

    it "treats a different approver as a disagreement even when the decision matches" do
      to_manager = rule("big", { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
        { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
      to_finance = rule("big", { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
        { "decision" => "require_approval", "approvers" => [ "role:finance_lead" ] })

      expect(described_class.compare([ to_manager ], [ to_finance ]).score).to be < 1.0
    end

    it "scores 100% for two empty rule sets and 0% for a missing rule" do
      expect(described_class.compare([], []).score).to eq(1.0)
      expect(described_class.compare(expected, []).score).to be < 1.0
    end
  end

  describe ".agreement" do
    it "is 100% when every output behaves the same, and drops with each outlier" do
      mistaken = [ rule("conference", conference_conditions.call("lt"), auto) ]

      expect(described_class.agreement([ expected, expected, expected ])).to eq(1.0)
      # 3 outputs, 1 outlier: pairs (a,b) agree fully, (a,c) and (b,c) agree on 2/3 of probes
      expect(described_class.agreement([ expected, expected, mistaken ])).to be_within(0.001).of((1 + 2 / 3.0 + 2 / 3.0) / 3)
    end

    it "is 100% for a single output, since there's nothing to disagree with" do
      expect(described_class.agreement([ expected ])).to eq(1.0)
    end
  end
end
