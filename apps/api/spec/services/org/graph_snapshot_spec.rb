require "rails_helper"

RSpec.describe Org::GraphSnapshot do
  describe ".load" do
    it "indexes people and departments by id with string-keyed attributes" do
      company = create(:company)
      department = create(:department, company: company)
      person = create(:person, company: company, department: department)

      snapshot = described_class.load(company)

      expect(snapshot.people.keys).to contain_exactly(person.id)
      expect(snapshot.people[person.id]["name"]).to eq(person.name)
      expect(snapshot.departments.keys).to contain_exactly(department.id)
      expect(snapshot.departments[department.id]["name"]).to eq(department.name)
    end

    it "only includes the given company's people and departments" do
      company = create(:company)
      other_company = create(:company)
      create(:person, company: other_company)
      create(:department, company: other_company)

      snapshot = described_class.load(company)

      expect(snapshot.people).to be_empty
      expect(snapshot.departments).to be_empty
    end
  end

  describe "#manager_of" do
    it "returns the person's manager_id" do
      company = create(:company)
      manager = create(:person, company: company)
      report = create(:person, company: company, manager: manager)
      snapshot = described_class.load(company)

      expect(snapshot.manager_of(report.id)).to eq(manager.id)
    end

    it "returns nil when the person has no manager" do
      company = create(:company)
      ceo = create(:person, :without_manager, company: company)
      snapshot = described_class.load(company)

      expect(snapshot.manager_of(ceo.id)).to be_nil
    end
  end

  describe "#holders_of" do
    it "returns the ids of people with the given role" do
      company = create(:company)
      finance_lead = create(:person, :finance_lead, company: company)
      create(:person, company: company) # no role

      snapshot = described_class.load(company)

      expect(snapshot.holders_of("finance_lead")).to contain_exactly(finance_lead.id)
    end

    it "returns an empty array when nobody holds the role" do
      company = create(:company)
      create(:person, company: company)
      snapshot = described_class.load(company)

      expect(snapshot.holders_of("finance_lead")).to eq([])
    end
  end

  describe "#head_of_dept" do
    it "returns the department's head_id" do
      company = create(:company)
      department = create(:department, company: company)
      head = create(:person, company: company, department: department)
      department.update!(head: head)
      snapshot = described_class.load(company)

      expect(snapshot.head_of_dept(department.id)).to eq(head.id)
    end

    it "returns nil when the department has no head" do
      company = create(:company)
      department = create(:department, company: company, head: nil)
      snapshot = described_class.load(company)

      expect(snapshot.head_of_dept(department.id)).to be_nil
    end
  end

  describe "#with_change" do
    it "returns a new snapshot and never mutates the original" do
      company = create(:company)
      manager = create(:person, company: company)
      report = create(:person, company: company, manager: manager)
      other_manager = create(:person, company: company)
      snapshot = described_class.load(company)

      changed = snapshot.with_change([
        { "op" => "change_manager", "person_id" => report.id, "to" => other_manager.id }
      ])

      expect(changed).not_to equal(snapshot)
      expect(snapshot.manager_of(report.id)).to eq(manager.id)
      expect(changed.manager_of(report.id)).to eq(other_manager.id)
    end

    it "applies a set_department_head operation" do
      company = create(:company)
      department = create(:department, company: company)
      new_head = create(:person, company: company, department: department)
      snapshot = described_class.load(company)

      changed = snapshot.with_change([
        { "op" => "set_department_head", "department_id" => department.id, "to" => new_head.id }
      ])

      expect(changed.head_of_dept(department.id)).to eq(new_head.id)
    end

    it "applies an assign_role operation" do
      company = create(:company)
      person = create(:person, company: company)
      snapshot = described_class.load(company)

      changed = snapshot.with_change([
        { "op" => "assign_role", "person_id" => person.id, "role" => "finance_lead" }
      ])

      expect(changed.holders_of("finance_lead")).to contain_exactly(person.id)
      expect(snapshot.holders_of("finance_lead")).to eq([])
    end

    it "applies multiple operations in order" do
      company = create(:company)
      manager = create(:person, company: company)
      report = create(:person, company: company, manager: manager)
      other_manager = create(:person, company: company)
      snapshot = described_class.load(company)

      changed = snapshot.with_change([
        { "op" => "change_manager", "person_id" => report.id, "to" => other_manager.id },
        { "op" => "assign_role", "person_id" => other_manager.id, "role" => "finance_lead" }
      ])

      expect(changed.manager_of(report.id)).to eq(other_manager.id)
      expect(changed.holders_of("finance_lead")).to contain_exactly(other_manager.id)
    end
  end
end
