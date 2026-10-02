# Streams one RuleResolution's outcome to the policy page once
# RuleResolutionJob finishes, and sends the current state on subscribe in
# case the job won the race. No auth yet, same as WorkflowEditChannel.
class RuleResolutionChannel < ApplicationCable::Channel
  def subscribed
    resolution = RuleResolution.find(params[:rule_resolution_id])
    stream_for resolution
    transmit resolution.as_payload
  end
end
