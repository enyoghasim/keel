require "rails_helper"

RSpec.describe Request, type: :model do
  it "is valid with a company, requester and kind" do
    expect(build(:request)).to be_valid
  end

  it "requires a kind" do
    request = build(:request, kind: nil)

    expect(request).not_to be_valid
    expect(request.errors[:kind]).to be_present
  end

  it "requires a requester" do
    request = build(:request, requester: nil)

    expect(request).not_to be_valid
    expect(request.errors[:requester]).to be_present
  end

  it "defaults to pending status with no recorded decision" do
    request = create(:request)

    expect(request.status).to eq("pending")
    expect(request.decision).to be_nil
    expect(request.matched_rule_ids).to eq([])
  end

  it "has at most one workflow run" do
    request = create(:request)
    workflow_run = create(:workflow_run, request: request)

    expect(request.reload.workflow_run).to eq(workflow_run)
  end
end
