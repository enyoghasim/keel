require "rails_helper"

RSpec.describe Department, type: :model do
  it "is valid with a company and a name" do
    expect(build(:department)).to be_valid
  end

  it "requires a name" do
    department = build(:department, name: nil)

    expect(department).not_to be_valid
    expect(department.errors[:name]).to be_present
  end

  it "requires a company" do
    department = build(:department, company: nil)

    expect(department).not_to be_valid
    expect(department.errors[:company]).to be_present
  end

  it "can have a head who is a person" do
    department = create(:department)
    head = create(:person, company: department.company, department: department)
    department.update!(head: head)

    expect(department.reload.head).to eq(head)
  end

  it "does not require a head" do
    expect(build(:department, head: nil)).to be_valid
  end
end
