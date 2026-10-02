require "rails_helper"

RSpec.describe EvalRun, type: :model do
  it "is valid with a company and a suite, and starts pending with no score" do
    eval_run = create(:eval_run)

    expect(eval_run).to have_attributes(status: "pending", accuracy: nil, cases_count: 0, passed_count: 0)
  end

  it "requires a known suite and status" do
    expect(build(:eval_run, suite: "vibes")).not_to be_valid
    expect(build(:eval_run, status: "nonsense")).not_to be_valid
  end
end
