require "rails_helper"

RSpec.describe Impact::Backtester do
  # Mirrors SPEC.md section 10's worked example: raising an auto-approve
  # limit flips some past expense decisions from manager approval to
  # auto-approve, and leaves everything else untouched.
  def request_for(person, payload) = Rules::RequestInput.new(requester_id: person.id, payload: payload)

  def expense_rule(limit)
    Rules::RuleDefinition.new(
      key: "expense_auto_approve",
      priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => limit },
      actions: { "decision" => "auto_approve" },
    )
  end

  it "reports requests whose decision flips between the old and new rule set" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)

    under_500 = request_for(requester, { "amount_eur" => 400 })
    between_500_and_800 = request_for(requester, { "amount_eur" => 650 })
    over_800 = request_for(requester, { "amount_eur" => 900 })
    requests = [ under_500, between_500_and_800, over_800 ]

    engine = Rules::Engine.new(Org::GraphSnapshot.load(company))
    report = described_class.call(engine: engine, requests: requests, before_rules: [ expense_rule(500) ], after_rules: [ expense_rule(800) ])

    expect(report.total).to eq(3)
    expect(report.flipped.map(&:request)).to eq([ between_500_and_800 ])
    flip = report.flipped.first
    expect(flip.before.outcome).to eq("require_approval")
    expect(flip.after.outcome).to eq("auto_approve")
  end

  it "reports no flips when the rule change doesn't affect any historical request" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)

    requests = [ request_for(requester, { "amount_eur" => 100 }), request_for(requester, { "amount_eur" => 100 }) ]

    engine = Rules::Engine.new(Org::GraphSnapshot.load(company))
    report = described_class.call(engine: engine, requests: requests, before_rules: [ expense_rule(500) ], after_rules: [ expense_rule(800) ])

    expect(report.total).to eq(2)
    expect(report.flipped).to eq([])
  end
end
