require "rails_helper"

RSpec.describe ChangeProposal, type: :model do
  it "is valid with a company, kind, title and diff" do
    expect(build(:change_proposal)).to be_valid
  end

  it "requires a title" do
    change_proposal = build(:change_proposal, title: nil)

    expect(change_proposal).not_to be_valid
    expect(change_proposal.errors[:title]).to be_present
  end

  it "requires kind to be one of org, rule or workflow" do
    change_proposal = build(:change_proposal, kind: "nonsense")

    expect(change_proposal).not_to be_valid
    expect(change_proposal.errors[:kind]).to be_present
  end

  it "requires proposed_by to be agent or user" do
    change_proposal = build(:change_proposal, proposed_by: "robot")

    expect(change_proposal).not_to be_valid
    expect(change_proposal.errors[:proposed_by]).to be_present
  end

  it "defaults to pending status" do
    expect(create(:change_proposal).status).to eq("pending")
  end

  it "does not require a decider until one decides" do
    expect(build(:change_proposal, decided_by: nil, decided_at: nil)).to be_valid
  end

  describe "#apply_org_diff!" do
    it "applies a change_manager operation to the real person record" do
      company = create(:company)
      old_manager = create(:person, company: company)
      new_manager = create(:person, company: company)
      person = create(:person, company: company, manager: old_manager)
      change_proposal = create(:change_proposal, company: company,
        diff: [ { "op" => "change_manager", "person_id" => person.id, "to" => new_manager.id } ])

      change_proposal.apply_org_diff!(company)

      expect(person.reload.manager_id).to eq(new_manager.id)
    end

    it "applies a set_department_head operation to the real department record" do
      company = create(:company)
      department = create(:department, company: company)
      new_head = create(:person, company: company)
      change_proposal = create(:change_proposal, company: company,
        diff: [ { "op" => "set_department_head", "department_id" => department.id, "to" => new_head.id } ])

      change_proposal.apply_org_diff!(company)

      expect(department.reload.head_id).to eq(new_head.id)
    end

    it "applies an assign_role operation to the real person record" do
      company = create(:company)
      person = create(:person, company: company, roles: [])
      change_proposal = create(:change_proposal, company: company,
        diff: [ { "op" => "assign_role", "person_id" => person.id, "role" => "finance_lead" } ])

      change_proposal.apply_org_diff!(company)

      expect(person.reload.roles).to eq([ "finance_lead" ])
    end

    it "raises on an unknown operation" do
      company = create(:company)
      change_proposal = create(:change_proposal, company: company, diff: [ { "op" => "nonsense" } ])

      expect { change_proposal.apply_org_diff!(company) }.to raise_error(ArgumentError)
    end
  end
end
