require "rails_helper"

RSpec.describe Policy, type: :model do
  it "is valid with a company, title and category" do
    expect(build(:policy)).to be_valid
  end

  it "requires a title" do
    policy = build(:policy, title: nil)

    expect(policy).not_to be_valid
    expect(policy.errors[:title]).to be_present
  end

  it "rejects an unknown category" do
    policy = build(:policy, category: "snacks")

    expect(policy).not_to be_valid
    expect(policy.errors[:category]).to be_present
  end

  it "defaults to draft status and version 1" do
    policy = create(:policy)

    expect(policy.status).to eq("draft")
    expect(policy.version).to eq(1)
  end

  it "has many rules" do
    policy = create(:policy)
    rule = create(:rule, policy: policy)

    expect(policy.rules).to contain_exactly(rule)
  end
end
