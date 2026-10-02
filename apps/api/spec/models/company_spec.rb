require "rails_helper"

RSpec.describe Company, type: :model do
  it "is valid with a name" do
    expect(build(:company)).to be_valid
  end

  it "requires a name" do
    company = build(:company, name: nil)

    expect(company).not_to be_valid
    expect(company.errors[:name]).to be_present
  end

  it "destroys its departments and people when destroyed" do
    company = create(:company)
    department = create(:department, company: company)
    person = create(:person, company: company, department: department)

    company.destroy

    expect(Department.exists?(department.id)).to be false
    expect(Person.exists?(person.id)).to be false
  end

  describe "#active_rule_definitions" do
    it "returns only active rules from active policies of that category" do
      company = create(:company)
      active = create(:policy, company: company, category: "expense", status: "active")
      draft = create(:policy, company: company, category: "expense", status: "draft")
      leave = create(:policy, company: company, category: "leave", status: "active")
      create(:rule, policy: active, key: "live", status: "active")
      create(:rule, policy: active, key: "not_yet", status: "extracted")
      create(:rule, policy: draft, key: "draft_policy", status: "active")
      create(:rule, policy: leave, key: "leave_rule", status: "active")

      expect(company.active_rule_definitions("expense").map(&:key)).to eq([ "live" ])
    end
  end
end
