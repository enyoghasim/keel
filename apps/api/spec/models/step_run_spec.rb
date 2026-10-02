require "rails_helper"

RSpec.describe StepRun, type: :model do
  it "is valid with a workflow run and a step key" do
    expect(build(:step_run)).to be_valid
  end

  it "requires a step key" do
    step_run = build(:step_run, step_key: nil)

    expect(step_run).not_to be_valid
    expect(step_run.errors[:step_key]).to be_present
  end

  it "requires a workflow run" do
    step_run = build(:step_run, workflow_run: nil)

    expect(step_run).not_to be_valid
    expect(step_run.errors[:workflow_run]).to be_present
  end

  it "does not require a resolved person until it becomes active" do
    expect(build(:step_run, resolved_person: nil)).to be_valid
  end

  it "defaults to pending and not overridden" do
    step_run = create(:step_run)

    expect(step_run.status).to eq("pending")
    expect(step_run.overridden).to eq(false)
  end
end
