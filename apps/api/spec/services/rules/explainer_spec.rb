require "rails_helper"

RSpec.describe Rules::Explainer do
  describe ".call" do
    it "explains the winning rule's decision" do
      rule = Rules::RuleDefinition.new(
        key: "expense_conference_engineering",
        priority: 10,
        conditions: {},
        actions: { "decision" => "auto_approve" },
      )

      explanation = described_class.call(rule, {})

      expect(explanation).to eq("Auto approved — matched rule 'expense_conference_engineering'.")
    end

    it "explains when no rule matched and the default action applied" do
      explanation = described_class.call(nil, {})

      expect(explanation).to eq("No rule matched; the policy's default action applied.")
    end
  end
end
