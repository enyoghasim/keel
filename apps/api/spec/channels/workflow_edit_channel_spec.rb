require "rails_helper"

RSpec.describe WorkflowEditChannel, type: :channel do
  it "streams one edit's updates and sends its current state straight away" do
    edit = create(:workflow_edit, status: "failed", error_message: "nope")

    subscribe(workflow_edit_id: edit.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(edit)
    expect(transmissions.last).to include("id" => edit.id, "status" => "failed")
  end
end
