require "rails_helper"

RSpec.describe AgentChannel, type: :channel do
  it "streams one agent run's trace and sends its current state straight away" do
    agent_run = create(:agent_run, status: "running")
    create(:agent_step, agent_run: agent_run, position: 1)

    subscribe(agent_run_id: agent_run.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(agent_run)
    expect(transmissions.last).to include("event" => "run", "run" => include("id" => agent_run.id, "steps" => [ include("position" => 1) ]))
  end
end
