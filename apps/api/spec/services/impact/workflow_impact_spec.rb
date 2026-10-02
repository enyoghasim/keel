require "rails_helper"

RSpec.describe Impact::WorkflowImpact do
  # SPEC.md section 10 for a workflow change: a step-level diff plus the
  # same question the org analyzer asks — whose requests now flow
  # differently, and does a new step resolve to nobody? Answered by
  # dry-running the old and new workflow for every person; no LLM.
  let(:company) { create(:company) }
  let(:manager) { create(:person, company: company, name: "Tunde") }
  let!(:employee) { create(:person, company: company, manager: manager, location: "Lagos") }
  let!(:abuja_employee) { create(:person, company: company, manager: manager, location: "Abuja") }
  let(:approval) { { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" } }
  let(:notify) { { "key" => "hr_notify", "type" => "notify", "assignee" => "role:hr_admin" } }
  let(:workflow) { create(:workflow, company: company, steps: [ approval, notify ]) }
  let(:it_step) { { "key" => "it_setup", "type" => "task", "assignee" => "role:it_admin", "title" => "Set up accounts" } }

  before do
    policy = create(:policy, company: company, category: "expense", status: "active")
    create(:rule, policy: policy, status: "active", key: "expense_default",
      conditions: { "field" => "payload.amount_eur", "op" => "gte", "value" => 0 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
    create(:person, company: company, manager: manager, roles: [ "hr_admin" ])
  end

  def impact(after_steps) = described_class.call(company: company, workflow: workflow, after_steps: after_steps)

  it "classifies the step diff: added, removed, changed and moved" do
    expect(impact([ approval, it_step, notify ])["steps"]).to eq("added" => [ "it_setup" ], "removed" => [], "changed" => [], "moved" => [])
    expect(impact([ approval ])["steps"]).to include("removed" => [ "hr_notify" ])
    expect(impact([ approval, { **notify, "assignee" => "role:finance_lead" } ])["steps"]).to include("changed" => [ "hr_notify" ])
    expect(impact([ notify, approval ])["steps"]).to include("moved" => %w[hr_notify approval])
  end

  it "counts everyone whose steps change when a task step is added, and says who it resolves to" do
    it_admin = create(:person, company: company, manager: manager, roles: [ "it_admin" ])

    report = impact([ approval, it_step, notify ])

    expect(report["affected_count"]).to be >= 2
    sample = report["affected"].find { _1["person_id"] == employee.id }
    expect(sample["before"]).not_to include(a_hash_including("step_key" => "it_setup"))
    expect(sample["after"]).to include(a_hash_including("step_key" => "it_setup", "person_id" => it_admin.id))
    expect(report["broken"]).to eq([])
  end

  it "only affects the people a conditional step applies to" do
    create(:person, company: company, manager: manager, roles: [ "it_admin" ])
    lagos_only = { **it_step, "when" => { "field" => "requester.location", "op" => "eq", "value" => "Lagos" } }

    affected = impact([ approval, lagos_only, notify ])["affected"].pluck("person_id").uniq

    expect(affected).to include(employee.id)
    expect(affected).not_to include(abuja_employee.id)
  end

  it "flags a new step whose reference resolves to nobody as broken" do
    report = impact([ approval, it_step, notify ]) # nobody holds role:it_admin

    expect(report["broken"]).to include(a_hash_including("step_key" => "it_setup", "reference" => "role:it_admin"))
    expect(report["broken"].first["person_count"]).to be >= 2
  end

  it "reports nothing for an identical workflow" do
    report = impact([ approval, notify ])

    expect(report).to include("affected_count" => 0, "affected" => [], "broken" => [], "in_flight" => 0)
  end

  it "counts open step runs sitting on a step the change removes" do
    run = create(:workflow_run, workflow: workflow, request: create(:request, company: company, requester: employee))
    create(:step_run, workflow_run: run, step_key: "hr_notify", reference: "role:hr_admin")
    create(:step_run, workflow_run: run, step_key: "approval", reference: "person:#{manager.id}")

    expect(impact([ approval ])["in_flight"]).to eq(1)
  end
end
