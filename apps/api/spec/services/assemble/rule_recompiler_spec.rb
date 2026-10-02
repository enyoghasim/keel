require "rails_helper"

RSpec.describe Assemble::RuleRecompiler do
  # SPEC.md section 9's propose_rule_change: "Raise the auto-approve limit to
  # €800" — the model rewrites the affected rule as schema-valid data; it
  # may not invent rules, and it never decides whether the change applies.
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:policy) { create(:policy, category: "expense", status: "active") }
  let!(:rule) do
    create(:rule, policy: policy, status: "active", key: "expense_small_auto", priority: 10,
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
      actions: { "decision" => "auto_approve" }, source_quote: "Expenses up to €500 are auto-approved.")
  end

  def reply(rules) = instance_double(RubyLLM::Message, content: { "rules" => rules })

  def changed_rule(**overrides)
    {
      "key" => "expense_small_auto", "priority" => 10,
      "conditions" => { "field" => "payload.amount_eur", "op" => "lte", "value" => 800 },
      "actions" => { "decision" => "auto_approve" }, "source_quote" => rule.source_quote, "ambiguities" => []
    }.merge(overrides)
  end

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
  end

  it "returns the rewritten rule keyed by the existing rule's key, as a rule definition" do
    allow(chat).to receive(:ask).and_return(reply([ changed_rule ]))

    result = described_class.call(policy: policy, instruction: "Raise the auto-approve limit to €800")

    expect(result.keys).to eq([ "expense_small_auto" ])
    expect(result["expense_small_auto"]).to have_attributes(
      key: "expense_small_auto", priority: 10, actions: { "decision" => "auto_approve" },
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 800 }
    )
  end

  it "shows the model the current rules and the instruction" do
    allow(chat).to receive(:ask) do |prompt|
      expect(prompt).to include("expense_small_auto", "Raise the auto-approve limit to €800", "\"value\":500")
      reply([ changed_rule ])
    end

    described_class.call(policy: policy, instruction: "Raise the auto-approve limit to €800")
  end

  it "drops a rule the model returned unchanged" do
    allow(chat).to receive(:ask).and_return(reply([ changed_rule("conditions" => rule.conditions) ]))

    expect(described_class.call(policy: policy, instruction: "no-op")).to eq({})
  end

  it "refuses a rule that isn't already in the policy — rewriting only, never inventing" do
    allow(chat).to receive(:ask).and_return(reply([ changed_rule("key" => "expense_invented") ]))

    expect { described_class.call(policy: policy, instruction: "x") }
      .to raise_error(Assemble::RuleRecompiler::UnknownRule, /expense_invented/)
  end

  it "surfaces output that fails the schema twice" do
    allow(chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: { "rules" => [ { "key" => "x" } ] }))

    expect { described_class.call(policy: policy, instruction: "x") }.to raise_error(Llm::StructuredAsk::ValidationError)
  end
end
