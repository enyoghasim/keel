require "rails_helper"

RSpec.describe Agent::Tools::ProposeOrgChange do
  # SPEC.md section 9's "Change" example ("Move Sales under Ada"): the model
  # only structures the operations — the tool records a ChangeProposal with a
  # computed impact report and nothing about the org changes until a person
  # approves it.
  let(:company) { create(:company) }
  let(:hr) { create(:person, company: company, roles: [ "hr_admin" ]) }
  let(:agent_run) { create(:agent_run, company: company, person: hr) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: hr, agent_run: agent_run)) }
  let(:tunde) { create(:person, company: company, name: "Tunde Bakare") }
  let(:ada) { create(:person, company: company, name: "Ada Nwosu") }
  let(:ngozi) { create(:person, company: company, name: "Ngozi Eze", manager: tunde) }

  def call(args) = JSON.parse(tool.call(args))

  before do
    policy = create(:policy, company: company, category: "expense", status: "active")
    create(:rule, policy: policy, status: "active", key: "expense_default",
      conditions: { "field" => "payload.amount_eur", "op" => "gte", "value" => 0 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
  end

  it "creates a pending proposal linked to the run, with impact, and applies nothing" do
    result = call({
      "title" => "Move Ngozi under Ada",
      "operations" => [ { "op" => "change_manager", "person_id" => ngozi.id, "to" => ada.id } ]
    })

    proposal = ChangeProposal.find(result["proposal_id"])
    expect(proposal).to have_attributes(
      kind: "org", status: "pending", proposed_by: "agent", agent_run: agent_run, title: "Move Ngozi under Ada",
      diff: [ { "op" => "change_manager", "person_id" => ngozi.id, "from" => tunde.id, "to" => ada.id } ]
    )
    expect(proposal.impact["rerouted"].map { _1["person_id"] }).to include(ngozi.id)
    expect(result).to include("status" => "pending", "link" => "/proposals", "rerouted" => 1, "broken" => 0)
    expect(result["note"]).to match(/nothing has changed/i)
    expect(ngozi.reload.manager_id).to eq(tunde.id)
  end

  it "fills in the previous department head on set_department_head" do
    sales = create(:department, company: company, name: "Sales", head: tunde)

    call({ "title" => "Ada heads Sales", "operations" => [ { "op" => "set_department_head", "department_id" => sales.id, "to" => ada.id } ] })

    expect(ChangeProposal.last.diff).to eq([ { "op" => "set_department_head", "department_id" => sales.id, "from" => tunde.id, "to" => ada.id } ])
  end

  it "reports a change that would leave a reference resolving to nobody" do
    result = call({ "title" => "Orphan Ngozi", "operations" => [ { "op" => "change_manager", "person_id" => ngozi.id, "to" => nil } ] })

    expect(result["broken"]).to be >= 1
  end

  it "refuses anyone who isn't an hr_admin" do
    employee = create(:person, company: company)
    tool = described_class.new(Agent::Context.new(company: company, person: employee, agent_run: agent_run))

    result = JSON.parse(tool.call({ "title" => "x", "operations" => [ { "op" => "assign_role", "person_id" => employee.id, "role" => "hr_admin" } ] }))

    expect(result["error"]).to match(/hr_admin/)
    expect(ChangeProposal.count).to eq(0)
  end

  it "rejects operations that point at people or departments outside the company" do
    stranger = create(:person)

    result = call({ "title" => "x", "operations" => [ { "op" => "change_manager", "person_id" => stranger.id, "to" => ada.id } ] })

    expect(result["error"]).to match(/not found/i)
    expect(ChangeProposal.count).to eq(0)
  end

  it "rejects an operation missing a required field" do
    result = call({ "title" => "x", "operations" => [ { "op" => "move_person", "person_id" => ngozi.id } ] })

    expect(result["error"]).to match(/department_id/)
  end

  it "returns the same proposal when the model repeats the call within a run" do
    args = { "title" => "Move Ngozi under Ada", "operations" => [ { "op" => "change_manager", "person_id" => ngozi.id, "to" => ada.id } ] }

    first = call(args)
    again = call(args)

    expect(again["proposal_id"]).to eq(first["proposal_id"])
    expect(ChangeProposal.count).to eq(1)
  end
end
