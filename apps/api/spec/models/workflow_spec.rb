require "rails_helper"

RSpec.describe Workflow, type: :model do
  it "is valid with a company, name and status" do
    expect(build(:workflow)).to be_valid
  end

  it "requires a name" do
    workflow = build(:workflow, name: nil)

    expect(workflow).not_to be_valid
    expect(workflow.errors[:name]).to be_present
  end

  it "requires a company" do
    workflow = build(:workflow, company: nil)

    expect(workflow).not_to be_valid
    expect(workflow.errors[:company]).to be_present
  end

  it "rejects an unknown status" do
    workflow = build(:workflow, status: "archived")

    expect(workflow).not_to be_valid
    expect(workflow.errors[:status]).to be_present
  end

  it "stores trigger and steps as structured data" do
    workflow = create(:workflow, trigger: { "request_kind" => "equipment" }, steps: [ { "key" => "manager", "type" => "approval" } ])

    expect(workflow.reload.trigger).to eq({ "request_kind" => "equipment" })
    expect(workflow.reload.steps).to eq([ { "key" => "manager", "type" => "approval" } ])
  end
end
