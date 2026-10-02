require "rails_helper"

RSpec.describe Impact::RuleImpact do
  # SPEC.md section 10's backtest example: raising an auto-approve limit and
  # counting which past decisions would have flipped — numbers from the
  # engine, sentence from a template.
  let(:company) { create(:company) }
  let(:manager) { create(:person, company: company) }
  let(:employee) { create(:person, company: company, manager: manager) }
  let(:policy) { create(:policy, company: company, category: "expense", status: "active") }
  let!(:limit_rule) do
    create(:rule, policy: policy, status: "active", key: "expense_small_auto", priority: 10,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" })
  end
  let!(:default_rule) do
    create(:rule, policy: policy, status: "active", key: "expense_default", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "gte", "value" => 0 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
  end
  let(:raised) do
    Rules::RuleDefinition.new(key: "expense_small_auto", priority: 10,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 800 }, actions: { "decision" => "auto_approve" })
  end

  before do
    [ 100, 450, 600, 700, 900 ].each { create(:request, company: company, requester: employee, kind: "expense", payload: { "amount_eur" => _1 }) }
    create(:request, company: company, requester: employee, kind: "leave", payload: { "days" => 3 })
  end

  it "replays past requests of the policy's kind and lists the decisions that flip" do
    impact = described_class.call(company: company, policy: policy, after_rules: { "expense_small_auto" => raised })

    backtest = impact["backtest"]
    expect(backtest).to include("total" => 5, "flipped_count" => 2)
    expect(backtest["flipped"].map { _1["payload"]["amount_eur"] }).to contain_exactly(600, 700)
    expect(backtest["flipped"].first).to include("before" => "require_approval", "after" => "auto_approve")
  end

  it "phrases the result from a template, naming how the outcomes moved" do
    summary = described_class.call(company: company, policy: policy, after_rules: { "expense_small_auto" => raised })["backtest"]["summary"]

    expect(summary).to eq("This would have changed 2 of 5 past expense decisions: 2 would have been auto-approved instead of sent for approval.")
  end

  it "says so when nothing would have changed" do
    same = Rules::RuleDefinition.new(key: "expense_small_auto", priority: 10, conditions: limit_rule.conditions, actions: limit_rule.actions)

    backtest = described_class.call(company: company, policy: policy, after_rules: { "expense_small_auto" => same })["backtest"]

    expect(backtest).to include("flipped_count" => 0, "summary" => "This would not have changed any of the 5 past expense decisions.")
  end
end
