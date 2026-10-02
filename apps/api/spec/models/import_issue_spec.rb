require "rails_helper"

RSpec.describe ImportIssue, type: :model do
  it "is valid with a company, row number, field and message" do
    expect(build(:import_issue)).to be_valid
  end

  it "requires a row number" do
    issue = build(:import_issue, row_number: nil)

    expect(issue).not_to be_valid
    expect(issue.errors[:row_number]).to be_present
  end

  it "requires a field" do
    issue = build(:import_issue, field: nil)

    expect(issue).not_to be_valid
    expect(issue.errors[:field]).to be_present
  end

  it "requires a message" do
    issue = build(:import_issue, message: nil)

    expect(issue).not_to be_valid
    expect(issue.errors[:message]).to be_present
  end

  it "defaults to unresolved" do
    expect(create(:import_issue).resolved).to eq(false)
  end
end
