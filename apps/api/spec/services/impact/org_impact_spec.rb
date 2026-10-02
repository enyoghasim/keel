require "rails_helper"

RSpec.describe Impact::OrgImpact do
  # SPEC.md section 10's "Move Sales under Ada": the one place that turns an
  # org diff into the stored impact JSON, shared by the HTTP controller and
  # the agent's propose_org_change tool.
  let(:company) { create(:company) }
  let(:old_manager) { create(:person, company: company, name: "Tunde") }
  let(:new_manager) { create(:person, company: company, name: "Ada") }
  let(:employee) { create(:person, company: company, manager: old_manager) }
  let(:diff) { [ { "op" => "change_manager", "person_id" => employee.id, "to" => new_manager.id } ] }

  before do
    policy = create(:policy, company: company, category: "expense", status: "active")
    create(:rule, policy: policy, status: "active", key: "expense_default",
      conditions: { "field" => "payload.amount_eur", "op" => "gte", "value" => 0 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
  end

  it "reports who is rerouted, as the JSON stored on a proposal" do
    impact = described_class.call(company: company, diff: diff)

    expect(impact.keys).to eq(%w[rerouted broken self_approval approval_load_changes rerouted_in_flight])
    rerouted = impact["rerouted"].select { _1["person_id"] == employee.id }
    expect(rerouted).not_to be_empty
    expect(rerouted.first["before"]["approvers"]).to eq([ old_manager.id ])
    expect(rerouted.first["after"]["approvers"]).to eq([ new_manager.id ])
    expect(impact["broken"]).to be_empty
  end

  it "copes with leave rules that look at notice_days, which the leave scenario must therefore supply" do
    leave = create(:policy, company: company, category: "leave", status: "active")
    create(:rule, policy: leave, status: "active", key: "leave_short_notice", priority: 2,
      conditions: { "all" => [ { "field" => "payload.days", "op" => "gt", "value" => 3 }, { "field" => "payload.notice_days", "op" => "lt", "value" => 14 } ] },
      actions: { "decision" => "reject", "reason" => "needs notice" })
    create(:rule, policy: leave, status: "active", key: "leave_default", priority: 1,
      conditions: { "field" => "payload.days", "op" => "gte", "value" => 1 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })

    impact = described_class.call(company: company, diff: diff)

    leave_reroutes = impact["rerouted"].select { _1["person_id"] == employee.id && _1["before"]["rule_keys"].include?("leave_default") }
    expect(leave_reroutes.first["after"]["approvers"]).to eq([ new_manager.id ]) # well-noticed leave is routed, not rejected
  end

  it "flags a change that leaves a reference resolving to nobody" do
    impact = described_class.call(company: company, diff: [ { "op" => "change_manager", "person_id" => employee.id, "to" => nil } ])

    expect(impact["broken"].map { _1["person_id"] }).to include(employee.id)
  end
end
