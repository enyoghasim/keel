require "rails_helper"

RSpec.describe Agent::Tools::CreateRequest do
  # SPEC.md section 9's "Act" example: "Request leave for 22–29 December" —
  # the runtime starts the workflow and the tool reports who must approve.
  let(:company) { create(:company) }
  let(:manager) { create(:person, company: company, name: "Tunde Bakare") }
  let(:asker) { create(:person, company: company, manager: manager) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }

  def call(args) = JSON.parse(tool.call(args))

  before do
    policy = create(:policy, company: company, category: "leave", status: "active")
    create(:rule, policy: policy, status: "active", key: "leave_needs_manager",
      conditions: { "field" => "payload.days", "op" => "gte", "value" => 1 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
    create(:workflow, company: company, status: "active", trigger: { "request_kind" => "leave" },
      steps: [ { "key" => "approval", "type" => "approval" } ])
  end

  it "files a real request for the current person and reports who it's waiting on" do
    result = call({ "request_kind" => "leave", "payload" => { "days" => 6 } })

    request = Request.find(result["request_id"])
    expect(request).to have_attributes(requester: asker, kind: "leave", status: "pending", decision: "require_approval")
    expect(result["steps"]).to eq([
      { "step" => "approval", "status" => "pending", "assignee" => "Tunde Bakare", "assignee_reference" => "person:#{manager.id}" }
    ])
  end

  it "returns the same request when the model repeats the call within a run" do
    first = call({ "request_kind" => "leave", "payload" => { "days" => 6 } })
    again = call({ "request_kind" => "leave", "payload" => { "days" => 6 } })

    expect(again["request_id"]).to eq(first["request_id"])
    expect(Request.count).to eq(1)
  end

  it "passes the runtime's refusal back to the model instead of crashing the run" do
    result = call({ "request_kind" => "equipment", "payload" => { "amount_eur" => 900 } })

    expect(result["error"]).to be_present
    expect(Request.count).to eq(0)
  end
end
