require "rails_helper"
require Rails.root.join("db/seeds/prompts")

RSpec.describe Seeds::Prompts do
  it "creates a weak v1 and a stronger active v2 of the policy extractor prompt" do
    described_class.call

    v1, v2 = PromptVersion.where(key: "policy_extractor").order(:version)
    expect(v1.template).not_to include("verbatim")
    expect(v2.template).to include("verbatim", "ambiguities")
    expect(v2).to be_active
    expect(v1).not_to be_active
  end

  it "creates a weak v1 and a stronger active v2 of the agent's system prompt" do
    described_class.call

    v1, v2 = PromptVersion.where(key: "agent_system").order(:version)
    expect(v1.template).not_to include("check_policy")
    expect(v2.template).to include("check_policy", "{{person_name}}")
    expect(v2).to be_active
    expect(v1).not_to be_active
  end

  it "is idempotent and doesn't override a promotion made since" do
    described_class.call
    PromptVersion.find_by!(key: "policy_extractor", version: 1).promote!

    expect { described_class.call }.not_to change(PromptVersion, :count)
    expect(PromptVersion.active_for("policy_extractor").version).to eq(1)
  end
end
