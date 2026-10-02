require "rails_helper"

RSpec.describe Agent::Tools::WhoApproves do
  # Workflows::Runtime#dry_run: how a request would route right now, with
  # nothing saved — approvers and the task/notify steps around them.
  let(:company) { create(:company) }
  let(:finance_lead) { create(:person, company: company, name: "Amaka Obi", roles: [ "finance_lead" ]) }
  let(:manager) { create(:person, company: company, name: "Tunde Bakare") }
  let(:asker) { create(:person, company: company, manager: manager) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }
  let(:policy) { create(:policy, company: company, category: "expense", status: "active") }

  def call(args) = JSON.parse(tool.call(args))

  before do
    finance_lead
    create(:rule, policy: policy, status: "active", key: "big", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 2000 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)", "role:finance_lead" ] })
    create(:workflow, company: company, steps: [
      { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" },
      { "key" => "finance", "type" => "notify", "assignee" => "role:finance_lead", "when" => { "field" => "payload.amount_eur", "op" => "gt", "value" => 1500 } }
    ])
  end

  it "lists the approval route for a request as the current person, resolved against today's graph" do
    result = call({ "request_kind" => "expense", "payload" => { "amount_eur" => 2500 } })

    expect(result["outcome"]).to eq("require_approval")
    approvals = result["steps"].select { _1["type"] == "approval" }
    expect(approvals.map { _1.dig("person", "name") }).to eq([ "Tunde Bakare", "Amaka Obi" ])
    expect(result["steps"].last).to include("step" => "finance", "type" => "notify", "applies" => true)
  end

  it "can route a request for someone else in the company" do
    other = create(:person, company: company, manager: finance_lead)

    result = call({ "request_kind" => "expense", "payload" => { "amount_eur" => 2500 }, "person_id" => other.id })

    expect(result["steps"].first.dig("person", "name")).to eq("Amaka Obi")
  end

  it "says so when no workflow handles the request kind" do
    expect(call({ "request_kind" => "leave", "payload" => { "days" => 5 } })).to include("error" => a_string_matching(/no active workflow/i))
  end
end
