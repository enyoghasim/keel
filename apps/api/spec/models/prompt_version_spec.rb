require "rails_helper"

RSpec.describe PromptVersion, type: :model do
  it "is valid with a key, version and template" do
    expect(build(:prompt_version)).to be_valid
  end

  it "keeps version numbers unique per key" do
    create(:prompt_version, key: "policy_extractor", version: 1)

    expect(build(:prompt_version, key: "policy_extractor", version: 1)).not_to be_valid
    expect(build(:prompt_version, key: "agent_system", version: 1)).to be_valid
  end

  describe ".active_for" do
    it "returns the active version of a key, or nil when none is active" do
      create(:prompt_version, version: 1)
      active = create(:prompt_version, version: 2, active: true)

      expect(described_class.active_for("policy_extractor")).to eq(active)
      expect(described_class.active_for("agent_system")).to be_nil
    end
  end

  describe "#promote!" do
    it "makes this version the only active one for its key, leaving other keys alone" do
      old = create(:prompt_version, version: 1, active: true)
      other_key = create(:prompt_version, key: "agent_system", version: 1, active: true)
      challenger = create(:prompt_version, version: 2)

      challenger.promote!

      expect(challenger.reload).to be_active
      expect(old.reload).not_to be_active
      expect(other_key.reload).to be_active
    end
  end

  describe "#render" do
    it "fills {{placeholders}} and fails loudly on one it wasn't given" do
      version = build(:prompt_version, template: "Rules for {{category}}: {{excerpt}}")

      expect(version.render(category: "expense", excerpt: "text")).to eq("Rules for expense: text")
      expect { version.render(category: "expense") }.to raise_error(KeyError, /excerpt/)
    end
  end
end
