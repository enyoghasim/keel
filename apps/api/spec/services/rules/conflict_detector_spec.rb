require "rails_helper"

RSpec.describe Rules::ConflictDetector do
  # Mirrors SPEC.md section 7's worked example: a travel rule and an expense
  # rule disagree over the same band of amounts.
  def rule(key:, priority:, decision:, conditions:)
    Rules::RuleDefinition.new(key: key, priority: priority, conditions: conditions, actions: { "decision" => decision })
  end

  it "flags two same-priority rules that disagree over an overlapping amount range" do
    travel_auto_approve = rule(
      key: "T2", priority: 5, decision: "auto_approve",
      conditions: {
        "all" => [
          { "field" => "payload.category", "op" => "eq", "value" => "travel" },
          { "field" => "payload.amount_eur", "op" => "lt", "value" => 800 }
        ]
      }
    )
    expense_needs_approval = rule(
      key: "E1", priority: 5, decision: "require_approval",
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 }
    )

    conflicts = described_class.call([ travel_auto_approve, expense_needs_approval ])

    expect(conflicts.size).to eq(1)
    conflict = conflicts.first
    expect([ conflict.rule_a_key, conflict.rule_b_key ]).to contain_exactly("T2", "E1")
    expect(conflict.probes).to include({ "payload.category" => "travel", "payload.amount_eur" => 501 })
  end

  it "does not flag rules whose amount ranges don't overlap" do
    low = rule(key: "low", priority: 1, decision: "auto_approve", conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 })
    high = rule(key: "high", priority: 1, decision: "require_approval", conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 })

    expect(described_class.call([ low, high ])).to eq([])
  end

  it "does not flag same-priority rules that overlap but agree on the outcome" do
    under_1000 = rule(key: "under_1000", priority: 1, decision: "auto_approve", conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 })
    travel = rule(key: "travel", priority: 1, decision: "auto_approve", conditions: { "field" => "payload.category", "op" => "eq", "value" => "travel" })

    expect(described_class.call([ under_1000, travel ])).to eq([])
  end

  it "does not flag overlapping rules at different priorities, since the higher priority wins deterministically" do
    low_priority = rule(key: "low_priority", priority: 1, decision: "auto_approve", conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 })
    high_priority = rule(key: "high_priority", priority: 10, decision: "reject", conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 })

    expect(described_class.call([ low_priority, high_priority ])).to eq([])
  end

  it "crosses department values mentioned via `in` with amount boundaries" do
    small_in_engineering_or_sales = rule(
      key: "dept_small", priority: 3, decision: "auto_approve",
      conditions: {
        "all" => [
          { "field" => "requester.department", "op" => "in", "value" => [ "Engineering", "Sales" ] },
          { "field" => "payload.amount_eur", "op" => "lte", "value" => 300 }
        ]
      }
    )
    sales_needs_approval = rule(
      key: "sales_approval", priority: 3, decision: "require_approval",
      conditions: {
        "all" => [
          { "field" => "requester.department", "op" => "eq", "value" => "Sales" },
          { "field" => "payload.amount_eur", "op" => "gt", "value" => 200 }
        ]
      }
    )

    conflicts = described_class.call([ small_in_engineering_or_sales, sales_needs_approval ])

    expect(conflicts.size).to eq(1)
    expect(conflicts.first.probes).to include({ "requester.department" => "Sales", "payload.amount_eur" => 201 })
  end

  it "does not probe a pair whose full actions differ only in decision label match (same actions)" do
    a = rule(key: "a", priority: 1, decision: "auto_approve", conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 })
    b = rule(key: "b", priority: 1, decision: "auto_approve", conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 })

    expect(described_class.call([ a, b ])).to eq([])
  end
end
