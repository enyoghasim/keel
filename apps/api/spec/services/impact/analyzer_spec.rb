require "rails_helper"

RSpec.describe Impact::Analyzer do
  # Mirrors SPEC.md section 10's four classifications, one example each,
  # plus the approval-load aggregate and the no-op case.
  def snapshot_for(company) = Org::GraphSnapshot.load(company)

  def scenario(payload: {}, rules: []) = { payload: payload, rules: rules }

  it "classifies a changed approver chain as rerouted" do
    company = create(:company)
    tunde = create(:person, company: company)
    ada = create(:person, company: company)
    ngozi = create(:person, company: company, manager: tunde)

    diff = [ { "op" => "change_manager", "person_id" => ngozi.id, "to" => ada.id } ]

    report = described_class.call(snapshot: snapshot_for(company), diff: diff, scenarios: [ scenario ])

    expect(report.rerouted.map(&:person_id)).to eq([ ngozi.id ])
    rerouted = report.rerouted.first
    expect(rerouted.before.approvers).to eq([ tunde.id ])
    expect(rerouted.after.approvers).to eq([ ada.id ])
    expect(report.broken).to eq([])
    expect(report.self_approval).to eq([])
  end

  it "classifies a reference that resolves to nobody as broken" do
    company = create(:company)
    sales = create(:department, company: company)
    head = create(:person, company: company)
    sales.update!(head: head)
    requester = create(:person, company: company, department: sales)

    needs_head_approval = Rules::RuleDefinition.new(
      key: "needs_head_approval", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 1000 },
      actions: { "decision" => "require_approval", "approvers" => [ "head_of(requester.department)" ] },
    )
    diff = [ { "op" => "set_department_head", "department_id" => sales.id, "to" => nil } ]

    report = described_class.call(
      snapshot: snapshot_for(company), diff: diff,
      scenarios: [ scenario(payload: { "amount_eur" => 3000 }, rules: [ needs_head_approval ]) ]
    )

    expect(report.broken.map(&:person_id)).to eq([ requester.id ])
    expect(report.broken.first.after.errors).to eq([ "head_of(requester.department) resolved to nobody" ])
    expect(report.rerouted).to eq([])
    expect(report.self_approval).to eq([])
  end

  it "classifies someone becoming their own approver as self-approval" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)

    diff = [ { "op" => "change_manager", "person_id" => requester.id, "to" => requester.id } ]

    report = described_class.call(snapshot: snapshot_for(company), diff: diff, scenarios: [ scenario ])

    expect(report.self_approval.map(&:person_id)).to eq([ requester.id ])
    expect(report.self_approval.first.after.errors).to eq([ "self-approval" ])
    expect(report.rerouted).to eq([])
    expect(report.broken).to eq([])
  end

  it "reports the approval load change for every approver whose chain count shifts" do
    company = create(:company)
    tunde = create(:person, company: company)
    ada = create(:person, company: company)
    ngozi = create(:person, company: company, manager: tunde)

    diff = [ { "op" => "change_manager", "person_id" => ngozi.id, "to" => ada.id } ]

    report = described_class.call(snapshot: snapshot_for(company), diff: diff, scenarios: [ scenario ])

    expect(report.approval_load_changes).to contain_exactly(
      { approver_id: tunde.id, before: 1, after: 0 },
      { approver_id: ada.id, before: 0, after: 1 }
    )
  end

  it "reports nothing when the change doesn't affect any scenario's routing" do
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)

    diff = [ { "op" => "assign_role", "person_id" => requester.id, "role" => "it_admin" } ]

    report = described_class.call(snapshot: snapshot_for(company), diff: diff, scenarios: [ scenario ])

    expect(report.rerouted).to eq([])
    expect(report.broken).to eq([])
    expect(report.self_approval).to eq([])
    expect(report.approval_load_changes).to eq([])
  end
end
