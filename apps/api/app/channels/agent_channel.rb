# Streams one AgentRun's trace to the command bar and trace drawer while
# AgentJob runs it, sending the run's current state on subscribe so a
# late subscriber misses nothing. No auth yet, same as the other channels.
class AgentChannel < ApplicationCable::Channel
  def subscribed
    agent_run = AgentRun.find(params[:agent_run_id])
    stream_for agent_run
    transmit({ "event" => "run", "run" => agent_run.as_payload })
  end
end
