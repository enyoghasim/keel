require "rails_helper"

RSpec.describe Person, type: :model do
  it "is valid with a company, name and email" do
    expect(build(:person)).to be_valid
  end

  it "requires a name" do
    person = build(:person, name: nil)

    expect(person).not_to be_valid
    expect(person.errors[:name]).to be_present
  end

  it "requires an email" do
    person = build(:person, email: nil)

    expect(person).not_to be_valid
    expect(person.errors[:email]).to be_present
  end

  it "requires email to be unique within a company" do
    company = create(:company)
    create(:person, company: company, email: "ada@factorial.example")
    duplicate = build(:person, company: company, email: "ada@factorial.example")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "allows the same email across different companies" do
    create(:person, email: "ada@factorial.example")
    other_company_person = build(:person, email: "ada@factorial.example")

    expect(other_company_person).to be_valid
  end

  it "does not require a department" do
    expect(build(:person, department: nil)).to be_valid
  end

  it "does not require a manager" do
    expect(build(:person, :without_manager)).to be_valid
  end

  it "can have direct reports" do
    manager = create(:person)
    report = create(:person, company: manager.company, manager: manager)

    expect(manager.direct_reports).to contain_exactly(report)
  end

  describe "#hr_admin?" do
    it "is true when the person has the hr_admin role" do
      expect(build(:person, :hr_admin)).to be_hr_admin
    end

    it "is false otherwise" do
      expect(build(:person, roles: [])).not_to be_hr_admin
    end
  end

  describe "password" do
    it "defaults to the demo password when none is given" do
      person = create(:person)

      expect(person.authenticate(Person::DEMO_PASSWORD)).to eq(person)
    end

    it "accepts an explicit password instead of the default" do
      person = create(:person, password: "a-custom-password")

      expect(person.authenticate("a-custom-password")).to eq(person)
      expect(person.authenticate(Person::DEMO_PASSWORD)).to be_falsey
    end
  end
end
