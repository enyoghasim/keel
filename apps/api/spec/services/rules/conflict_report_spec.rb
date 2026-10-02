require "rails_helper"

RSpec.describe Rules::ConflictReport do
  # SPEC.md section 7's example: travel under €800 auto-approves, any expense
  # over €500 needs approval, same priority. The report says so in words and
  # suggests the usual fix — let the narrower rule win — without any LLM.
  def rule(key:, priority: 1, decision:, conditions:)
    Rules::RuleDefinition.new(key: key, priority: priority, conditions: conditions, actions: { "decision" => decision })
  end

  let(:travel) do
    rule(key: "travel_under_800", decision: "auto_approve", conditions: { "all" => [
      { "field" => "payload.category", "op" => "eq", "value" => "travel" },
      { "field" => "payload.amount_eur", "op" => "lt", "value" => 800 }
    ] })
  end
  let(:expense) { rule(key: "expense_over_500", decision: "require_approval", conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 }) }

  it "reports the conflict with a plain-English explanation and an example request" do
    entry = described_class.call([ expense, travel ]).sole

    expect([ entry.rule_a_key, entry.rule_b_key ]).to contain_exactly("travel_under_800", "expense_over_500")
    expect(entry.explanation).to include("travel_under_800", "expense_over_500", "auto approved", "sent for approval")
    expect(entry.example).to include("payload.category" => "travel")
    expect(entry.example["payload.amount_eur"]).to be_between(501, 799)
  end

  it "suggests raising the narrower rule above the other, so the specific exception wins" do
    entry = described_class.call([ expense, travel ]).sole

    expect(entry.fix).to eq(Rules::ConflictReport::Fix.new(rule_key: "travel_under_800", new_priority: 2))
  end

  it "suggests nothing when neither rule is narrower — that is a decision for a person" do
    other = rule(key: "other", decision: "auto_approve", conditions: { "field" => "payload.amount_eur", "op" => "lt", "value" => 900 })

    entry = described_class.call([ expense, other ]).sole

    expect(entry.fix).to be_nil
  end

  it "is empty when no rules conflict" do
    expect(described_class.call([ travel ])).to eq([])
  end
end
