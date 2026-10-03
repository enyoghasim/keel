require "rails_helper"

RSpec.describe AgentJob, type: :job do
  include ActionCable::TestHelper

  let(:agent_run) { create(:agent_run, message: "Hello") }

  it "runs the agent and broadcasts each step as it lands, then the finished run" do
    allow(RubyLLM).to receive(:chat).and_return(FakeChat.new([ { content: "Hi! How can I help?" } ]))

    expect { described_class.perform_now(agent_run.id) }
      .to have_broadcasted_to(agent_run).from_channel(AgentChannel)
      .with(hash_including("event" => "step", "step" => hash_including("kind" => "llm", "position" => 1)))
      .and have_broadcasted_to(agent_run).from_channel(AgentChannel)
      .with(hash_including("event" => "run", "run" => hash_including("status" => "completed", "final_text" => "Hi! How can I help?")))
  end

  it "broadcasts each piece of the final answer as the model streams it" do
    allow(RubyLLM).to receive(:chat).and_return(FakeChat.new([ { content: "Hi! How can I help?", chunks: [ "Hi! ", "How can I help?" ] } ]))

    expect { described_class.perform_now(agent_run.id) }
      .to have_broadcasted_to(agent_run).from_channel(AgentChannel).with(hash_including("event" => "delta", "text" => "Hi! "))
      .and have_broadcasted_to(agent_run).from_channel(AgentChannel).with(hash_including("event" => "delta", "text" => "Hi! How can I help?"))
  end

  it "doesn't re-run a run that has already started" do
    agent_run.update!(status: "completed")
    allow(Agent::Runner).to receive(:call)

    described_class.perform_now(agent_run.id)

    expect(Agent::Runner).not_to have_received(:call)
  end
end
