# Streams one WorkflowEdit's outcome to the /workflows page once
# WorkflowEditJob finishes. Sends the current state on subscribe too, in
# case the job won the race against the subscription. No auth yet, same as
# InsightChannel.
class WorkflowEditChannel < ApplicationCable::Channel
  def subscribed
    workflow_edit = WorkflowEdit.find(params[:workflow_edit_id])
    stream_for workflow_edit
    transmit workflow_edit.as_payload
  end
end
