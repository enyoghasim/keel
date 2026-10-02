require "rails_helper"

RSpec.describe Rules::Engine do
  # Mirrors SPEC.md section 5's worked example rule set: one example per
  # real-world scenario, not per method.
  let(:expense_conference_engineering) do
    Rules::RuleDefinition.new(
      key: "expense_conference_engineering",
      priority: 10,
      conditions: {
        "all" => [
          { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
          { "field" => "payload.category", "op" => "eq", "value" => "conference" },
          { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 }
        ]
      },
      actions: { "decision" => "auto_approve" },
    )
  end

  let(:expense_small) do
    Rules::RuleDefinition.new(
      key: "expense_small",
      priority: 5,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" },
    )
  end

  let(:expense_large) do
    Rules::RuleDefinition.new(
      key: "expense_large",
      priority: 8,
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 2000 },
      actions: {
        "decision" => "require_approval",
        "approvers" => [ "manager_of(requester)", "role:finance_lead" ]
      },
    )
  end

  let(:expense_rules) { [ expense_conference_engineering, expense_small, expense_large ] }

  def engine_for(company) = described_class.new(Org::GraphSnapshot.load(company))

  def request_for(person, payload) = Rules::RequestInput.new(requester_id: person.id, payload: payload)

  it "auto-approves an Engineering conference expense under the €1,000 limit" do
    company = create(:company)
    engineering = create(:department, company: company, name: "Engineering")
    requester = create(:person, company: company, department: engineering)
    request = request_for(requester, { "amount_eur" => 900, "category" => "conference" })

    decision = engine_for(company).evaluate(request, expense_rules)

    expect(decision.outcome).to eq("auto_approve")
    expect(decision.rule_keys).to eq([ "expense_conference_engineering" ])
    expect(decision.errors).to eq([])
  end

  it "sends an Engineering conference expense over €1,000 to the manager (default action)" do
    company = create(:company)
    engineering = create(:department, company: company, name: "Engineering")
    manager = create(:person, company: company)
    requester = create(:person, company: company, department: engineering, manager: manager)
    request = request_for(requester, { "amount_eur" => 1200, "category" => "conference" })

    decision = engine_for(company).evaluate(request, expense_rules)

    expect(decision.outcome).to eq("require_approval")
    expect(decision.rule_keys).to eq([])
    expect(decision.approvers).to eq([ manager.id ])
  end

  it "sends a large Sales travel expense to the manager and the finance lead" do
    company = create(:company)
    sales = create(:department, company: company, name: "Sales")
    manager = create(:person, company: company)
    finance_lead = create(:person, :finance_lead, company: company)
    requester = create(:person, company: company, department: sales, manager: manager)
    request = request_for(requester, { "amount_eur" => 2500, "category" => "travel" })

    decision = engine_for(company).evaluate(request, expense_rules)

    expect(decision.outcome).to eq("require_approval")
    expect(decision.rule_keys).to eq([ "expense_large" ])
    expect(decision.approvers).to contain_exactly(manager.id, finance_lead.id)
  end

  it "auto-approves any small expense under the small-expense rule" do
    company = create(:company)
    requester = create(:person, company: company)
    request = request_for(requester, { "amount_eur" => 300, "category" => "office_supplies" })

    decision = engine_for(company).evaluate(request, expense_rules)

    expect(decision.outcome).to eq("auto_approve")
    expect(decision.rule_keys).to eq([ "expense_small" ])
  end

  it "blocks with self-approval when the requester is the only resolved approver" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, :finance_lead, company: company, manager: manager)
    request = request_for(requester, { "amount_eur" => 2500, "category" => "travel" })

    decision = engine_for(company).evaluate(request, expense_rules)

    expect(decision.outcome).to eq("blocked")
    expect(decision.errors).to include("self-approval")
    expect(decision.approvers).to include(requester.id)
  end

  it "blocks when the default action's approver resolves to nobody (requester has no manager)" do
    company = create(:company)
    ceo = create(:person, :without_manager, company: company)
    request = request_for(ceo, { "amount_eur" => 700, "category" => "office_supplies" })

    decision = engine_for(company).evaluate(request, expense_rules)

    expect(decision.outcome).to eq("blocked")
    expect(decision.errors).to eq([ "manager_of(requester) resolved to nobody" ])
  end

  it "breaks a priority tie in favour of the more restrictive action" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)
    request = request_for(requester, { "amount_eur" => 800, "category" => "travel" })

    auto_approve_under_1000 = Rules::RuleDefinition.new(
      key: "auto_approve_under_1000",
      priority: 7,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 },
      actions: { "decision" => "auto_approve" },
    )
    travel_needs_approval = Rules::RuleDefinition.new(
      key: "travel_needs_approval",
      priority: 7,
      conditions: { "field" => "payload.category", "op" => "eq", "value" => "travel" },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] },
    )

    decision = engine_for(company).evaluate(request, [ auto_approve_under_1000, travel_needs_approval ])

    expect(decision.outcome).to eq("require_approval")
  end

  it "rejects leave with insufficient notice" do
    company = create(:company)
    requester = create(:person, company: company)
    request = request_for(requester, { "days" => 3, "notice_days" => 2 })

    notice_period_rule = Rules::RuleDefinition.new(
      key: "leave_notice_period",
      priority: 10,
      conditions: {
        "all" => [
          { "field" => "payload.days", "op" => "gte", "value" => 3 },
          { "field" => "payload.notice_days", "op" => "lt", "value" => 14 }
        ]
      },
      actions: { "decision" => "reject", "reason" => "insufficient notice" },
    )

    decision = engine_for(company).evaluate(request, [ notice_period_rule ])

    expect(decision.outcome).to eq("reject")
    expect(decision.rule_keys).to eq([ "leave_notice_period" ])
  end

  it "includes a plain-English explanation on the decision" do
    company = create(:company)
    engineering = create(:department, company: company, name: "Engineering")
    requester = create(:person, company: company, department: engineering)
    request = request_for(requester, { "amount_eur" => 900, "category" => "conference" })

    decision = engine_for(company).evaluate(request, expense_rules)

    expect(decision.explanation).to eq("Auto approved — matched rule 'expense_conference_engineering'.")
  end
end
