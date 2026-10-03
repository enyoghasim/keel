require "rails_helper"

RSpec.describe WorkflowEdit, type: :model do
  it "defaults to the instruction source and requires an instruction" do
    edit = create(:workflow_edit)

    expect(edit.source).to eq("instruction")
    expect(build(:workflow_edit, instruction: nil)).not_to be_valid
  end

  it "requires after_steps instead of an instruction when human-authored" do
    valid = build(:workflow_edit, source: "steps", instruction: nil, after_steps: [ { "key" => "approval", "type" => "approval" } ])
    expect(valid).to be_valid

    missing_steps = build(:workflow_edit, source: "steps", instruction: nil, after_steps: nil)
    expect(missing_steps).not_to be_valid
  end
end
