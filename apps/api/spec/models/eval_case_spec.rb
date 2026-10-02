require "rails_helper"

RSpec.describe EvalCase, type: :model do
  it "is valid with a suite, key, input and expected output" do
    expect(build(:eval_case)).to be_valid
  end

  it "requires suite to be one of the three suites" do
    expect(build(:eval_case, suite: "vibes")).not_to be_valid
  end

  it "requires a key unique within its suite" do
    create(:eval_case, suite: "insights", key: "leave_by_department")

    expect(build(:eval_case, suite: "insights", key: "leave_by_department")).not_to be_valid
    expect(build(:eval_case, suite: "agent", key: "leave_by_department")).to be_valid
  end

  it "only counts active cases as part of the suite, not candidates awaiting review" do
    active = create(:eval_case)
    create(:eval_case, status: "candidate")

    expect(described_class.active).to eq([ active ])
  end
end
