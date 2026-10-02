require "rails_helper"

RSpec.describe AgentRun, type: :model do
  it "is valid with a company, the person asking, and a message, and starts pending" do
    expect(create(:agent_run)).to have_attributes(status: "pending", total_tokens: 0, final_text: nil)
  end

  it "requires a message and a known status" do
    expect(build(:agent_run, message: "")).not_to be_valid
    expect(build(:agent_run, status: "thinking")).not_to be_valid
  end

  it "renders its steps in order as part of its payload" do
    agent_run = create(:agent_run)
    create(:agent_step, agent_run: agent_run, position: 2, kind: "llm", tool_name: nil, tokens: 300)
    create(:agent_step, agent_run: agent_run, position: 1, tool_name: "search_people")

    expect(agent_run.reload.as_payload["steps"].map { _1["position"] }).to eq([ 1, 2 ])
  end

  it "starts its own conversation unless it continues one, and exposes the conversation in its payload" do
    first = create(:agent_run)
    second = create(:agent_run, company: first.company, person: first.person, conversation_id: first.conversation_id)

    expect(first.conversation_id).to be_present
    expect(second.conversation_id).to eq(first.conversation_id)
    expect(create(:agent_run).conversation_id).not_to eq(first.conversation_id)
    expect(second.as_payload).to include("conversation_id" => first.conversation_id)
  end
end
