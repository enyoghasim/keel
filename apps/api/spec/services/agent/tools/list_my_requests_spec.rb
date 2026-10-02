require "rails_helper"

RSpec.describe Agent::Tools::ListMyRequests do
  let(:company) { create(:company) }
  let(:asker) { create(:person, company: company) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }

  def call(args = {}) = JSON.parse(tool.call(args))

  it "lists only the current person's requests, newest first, with who each is waiting on" do
    approver = create(:person, company: company, name: "Tunde Bakare")
    waiting = create(:request, company: company, requester: asker, status: "pending", payload: { "amount_eur" => 900 }, created_at: 1.day.ago)
    run = create(:workflow_run, request: waiting)
    create(:step_run, workflow_run: run, resolved_person: approver, status: "pending")
    done = create(:request, company: company, requester: asker, status: "approved", decision: "auto_approve", created_at: 3.days.ago)
    create(:request, company: company, status: "pending")

    result = call

    expect(result["requests"].map { _1["id"] }).to eq([ waiting.id, done.id ])
    expect(result["requests"].first).to include("kind" => "expense", "status" => "pending", "waiting_on" => "Tunde Bakare")
    expect(result["requests"].last).to include("status" => "approved", "waiting_on" => nil)
  end

  it "filters by status" do
    create(:request, company: company, requester: asker, status: "approved")
    pending = create(:request, company: company, requester: asker, status: "pending")

    expect(call({ "status" => "pending" })["requests"].map { _1["id"] }).to eq([ pending.id ])
  end
end
