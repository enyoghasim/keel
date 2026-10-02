# Runs one AgentRun with Agent::Runner (SPEC.md section 3's request
# lifecycle) and streams the trace on AgentChannel: each step as it's
# recorded, then the finished run with its answer.
class AgentJob < ApplicationJob
  def perform(agent_run_id)
    agent_run = AgentRun.find(agent_run_id)
    return unless agent_run.status == "pending"

    Agent::Runner.call(agent_run) do |step|
      AgentChannel.broadcast_to(agent_run, { "event" => "step", "step" => step.as_payload })
    end
    AgentChannel.broadcast_to(agent_run, { "event" => "run", "run" => agent_run.reload.as_payload })
  end
end
