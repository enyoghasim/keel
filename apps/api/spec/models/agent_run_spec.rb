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
end
