require "rails_helper"

RSpec.describe Agent::Tools::CheckPolicy do
  # SPEC.md section 9's "Ask" example: "Can I expense a €1,200 flight to
  # RubyConf?" — the engine decides, the tool reports who approves and
  # which handbook quote it rests on.
  let(:company) { create(:company) }
  let(:manager) { create(:person, company: company, name: "Tunde Bakare") }
  let(:asker) { create(:person, company: company, manager: manager) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }
  let(:policy) { create(:policy, company: company, category: "expense", status: "active") }

  def call(args) = JSON.parse(tool.call(args))

  before do
    create(:rule, policy: policy, status: "active", key: "small_expense", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" },
      source_quote: "Expenses up to €500 are approved automatically.",
      source_chunk: create(:chunk, page: 4, text: "Expenses up to €500 are approved automatically."))
    create(:rule, policy: policy, status: "active", key: "large_expense", priority: 2,
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] },
      source_quote: "Anything above €500 needs your manager's approval.",
      source_chunk: create(:chunk, page: 5, text: "Anything above €500 needs your manager's approval."))
  end

  it "evaluates the request as the current person, naming the approver and citing the handbook page" do
    result = call({ "request_kind" => "expense", "payload" => { "amount_eur" => 1200, "category" => "travel" } })

    expect(result["decision"]).to eq("require_approval")
    expect(result["approvers"].map { _1["name"] }).to eq([ "Tunde Bakare" ])
    expect(result["citations"]).to eq([
      { "rule" => "large_expense", "quote" => "Anything above €500 needs your manager's approval.", "page" => 5 }
    ])
    expect(result["explanation"]).to be_present
  end

  it "reports an auto-approval with no approvers" do
    result = call({ "request_kind" => "expense", "payload" => { "amount_eur" => 80 } })

    expect(result).to include("decision" => "auto_approve", "approvers" => [])
  end

  it "ignores rules that aren't active, so a draft can't answer a policy question" do
    policy.rules.update_all(status: "extracted")

    result = call({ "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } })

    expect(result["citations"]).to eq([])
  end
end
