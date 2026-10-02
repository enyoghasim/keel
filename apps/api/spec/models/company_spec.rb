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
end
