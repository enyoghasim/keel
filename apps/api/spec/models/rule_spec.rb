require "rails_helper"

RSpec.describe Rule, type: :model do
  it "is valid with a policy, source chunk, key and source quote" do
    expect(build(:rule)).to be_valid
  end

  it "requires a key" do
    rule = build(:rule, key: nil)

    expect(rule).not_to be_valid
    expect(rule.errors[:key]).to be_present
  end

  it "requires a source quote" do
    rule = build(:rule, source_quote: nil)

    expect(rule).not_to be_valid
    expect(rule.errors[:source_quote]).to be_present
  end

  it "requires a source chunk" do
    rule = build(:rule, source_chunk: nil)

    expect(rule).not_to be_valid
    expect(rule.errors[:source_chunk]).to be_present
  end

  it "defaults to extracted status and no ambiguities" do
    rule = create(:rule)

    expect(rule.status).to eq("extracted")
    expect(rule.ambiguities).to eq([])
  end

  it "converts into the plain Rules::RuleDefinition the engine evaluates" do
    rule = create(:rule)

    definition = rule.to_rule_definition

    expect(definition).to eq(Rules::RuleDefinition.new(
      key: rule.key, priority: rule.priority, conditions: rule.conditions, actions: rule.actions
    ))
  end
end
