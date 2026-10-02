require "rails_helper"

RSpec.describe AgentStep, type: :model do
  it "requires kind to be llm or tool" do
    expect(build(:agent_step, kind: "thought")).not_to be_valid
  end

  it "keeps positions unique within a run" do
    existing = create(:agent_step, position: 1)

    expect(build(:agent_step, agent_run: existing.agent_run, position: 1)).not_to be_valid
  end
end
