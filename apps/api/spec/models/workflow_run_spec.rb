require "rails_helper"

RSpec.describe WorkflowRun, type: :model do
  it "is valid with a request" do
    expect(build(:workflow_run)).to be_valid
  end

  it "requires a request" do
    workflow_run = build(:workflow_run, request: nil)

    expect(workflow_run).not_to be_valid
    expect(workflow_run.errors[:request]).to be_present
  end

  it "does not require a workflow, for system-decided requests" do
    expect(build(:workflow_run, workflow: nil)).to be_valid
  end

  it "has many step runs" do
    workflow_run = create(:workflow_run)
    step_run = create(:step_run, workflow_run: workflow_run)

    expect(workflow_run.step_runs).to contain_exactly(step_run)
  end
end
