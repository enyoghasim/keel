require "rails_helper"

RSpec.describe Agent::Tools::ProposeRuleChange do
  # SPEC.md section 9's "Raise the auto-approve limit to €800": the model's
  # rewrite is backtested against past requests and recorded as a pending
  # proposal — the live rules don't change until a person approves.
  let(:company) { create(:company) }
  let(:hr) { create(:person, company: company, roles: [ "hr_admin" ]) }
  let(:agent_run) { create(:agent_run, company: company, person: hr) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: hr, agent_run: agent_run)) }
  let(:employee) { create(:person, company: company, manager: hr) }
  let(:policy) { create(:policy, company: company, category: "expense", status: "active", title: "Expense Policy") }
  let!(:rule) do
    create(:rule, policy: policy, status: "active", key: "expense_small_auto", priority: 10,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 }, actions: { "decision" => "auto_approve" })
  end
  let(:raised) do
    Rules::RuleDefinition.new(key: "expense_small_auto", priority: 10,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 800 }, actions: { "decision" => "auto_approve" })
  end

  def call(args = { "policy_id" => policy.id, "instruction" => "Raise the auto-approve limit to €800" }) = JSON.parse(tool.call(args))

  before do
    [ 300, 600, 700 ].each { create(:request, company: company, requester: employee, kind: "expense", payload: { "amount_eur" => _1 }) }
    allow(Assemble::RuleRecompiler).to receive(:call).and_return({ "expense_small_auto" => raised })
  end

  it "records a pending rule proposal with the before/after rules and a backtest, linked to the run" do
    result = call

    proposal = ChangeProposal.find(result["proposal_id"])
    expect(proposal).to have_attributes(kind: "rule", status: "pending", proposed_by: "agent", agent_run: agent_run)
    expect(proposal.title).to include("Expense Policy")
    expect(proposal.diff).to include("policy_id" => policy.id)
    expect(proposal.diff["before"].first).to include("key" => "expense_small_auto", "conditions" => rule.conditions)
    expect(proposal.diff["after"].first).to include("key" => "expense_small_auto", "conditions" => raised.conditions)
    expect(proposal.diff["instruction"]).to eq("Raise the auto-approve limit to €800")
    expect(proposal.impact["backtest"]).to include("total" => 3, "flipped_count" => 2)
    expect(result).to include("status" => "pending", "link" => "/proposals", "flipped" => 2, "total" => 3)
    expect(result["summary"]).to match(/changed 2 of 3 past expense decisions/)
  end

  it "leaves the live rule untouched" do
    call

    expect(rule.reload.conditions["value"]).to eq(500)
  end

  it "keeps a link to the handbook source of each rule it rewrites" do
    call

    expect(ChangeProposal.last.diff["after"].first).to include("source_quote" => rule.source_quote, "source_chunk_id" => rule.source_chunk_id)
  end

  it "tells the model when the instruction changes nothing, creating no proposal" do
    allow(Assemble::RuleRecompiler).to receive(:call).and_return({})

    expect(call["error"]).to match(/not change any rule/i)
    expect(ChangeProposal.count).to eq(0)
  end

  it "refuses anyone who isn't an hr_admin" do
    tool = described_class.new(Agent::Context.new(company: company, person: employee, agent_run: agent_run))

    result = JSON.parse(tool.call({ "policy_id" => policy.id, "instruction" => "x" }))

    expect(result["error"]).to match(/hr_admin/)
    expect(Assemble::RuleRecompiler).not_to have_received(:call)
  end

  it "doesn't reach another company's policy" do
    other = create(:policy, category: "expense", status: "active")

    expect(call({ "policy_id" => other.id, "instruction" => "x" })["error"]).to match(/not found/i)
  end

  it "returns the same proposal when the model repeats the call within a run" do
    first = call
    again = call

    expect(again["proposal_id"]).to eq(first["proposal_id"])
    expect(ChangeProposal.count).to eq(1)
  end
end
