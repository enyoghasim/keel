require "rails_helper"

RSpec.describe Assemble::AmbiguityResolver do
  # SPEC.md section 7, "Ambiguity resolution": a person answers the question
  # a rule carries ("Ticket only"); the model only rewrites that rule's
  # conditions to say so, as schema-valid data, and the result is saved as a
  # new rule version — rules are never edited in place.
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:policy) { create(:policy, category: "expense", status: "draft") }
  let(:ambiguity) do
    { "phrase" => "up to €1,000", "question" => "Does the €1,000 conference limit include travel and hotel, or only the ticket?",
      "options" => [ "Ticket only", "Ticket, travel and hotel" ] }
  end
  let!(:rule) do
    create(:rule, policy: policy, status: "extracted", key: "expense_conference", priority: 3, ambiguities: [ ambiguity ],
      conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 },
      actions: { "decision" => "auto_approve" }, source_quote: "Engineers attending conferences are automatically approved up to €1,000.")
  end

  def reply(**overrides)
    rule_data = {
      "key" => "expense_conference", "priority" => 3,
      "conditions" => { "all" => [
        { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 },
        { "field" => "payload.category", "op" => "eq", "value" => "conference_ticket" }
      ] },
      "actions" => { "decision" => "auto_approve" }, "source_quote" => rule.source_quote, "ambiguities" => []
    }.merge(overrides)
    instance_double(RubyLLM::Message, content: { "rules" => [ rule_data ] }, cost: instance_double(RubyLLM::Cost, total: nil))
  end

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:ask).and_return(reply)
  end

  it "saves the rewritten rule as a new, resolved version and supersedes the old one" do
    result = described_class.call(rule: rule, ambiguity_index: 0, answer: "Ticket only")

    expect(result.before).to eq(rule)
    expect(rule.reload.status).to eq("superseded")
    expect(result.after).to have_attributes(
      key: "expense_conference", status: "resolved", ambiguities: [], priority: 3,
      source_chunk: rule.source_chunk, source_quote: rule.source_quote
    )
    expect(result.after.conditions["all"].last).to eq("field" => "payload.category", "op" => "eq", "value" => "conference_ticket")
    expect(policy.rules.where(key: "expense_conference").count).to eq(2)
  end

  it "shows the model the rule, the question and the answer" do
    allow(chat).to receive(:ask) do |prompt|
      expect(prompt).to include("expense_conference", ambiguity["question"], "Ticket only", rule.source_quote)
      reply
    end

    described_class.call(rule: rule, ambiguity_index: 0, answer: "Ticket only")
  end

  it "keeps the rule's other open questions open, so it stays unresolved until they are answered" do
    other = { "phrase" => "engineers", "question" => "Contractors too?", "options" => [ "Yes", "No" ] }
    rule.update!(ambiguities: [ ambiguity, other ])

    result = described_class.call(rule: rule, ambiguity_index: 0, answer: "Ticket only")

    expect(result.after).to have_attributes(status: "extracted", ambiguities: [ other ])
  end

  it "refuses an answer that is not one of the options, without calling the model" do
    expect { described_class.call(rule: rule, ambiguity_index: 0, answer: "Whatever") }
      .to raise_error(ArgumentError, /not one of the options/)
    expect(chat).not_to have_received(:ask)
  end

  it "refuses a question the rule doesn't have" do
    expect { described_class.call(rule: rule, ambiguity_index: 4, answer: "Ticket only") }
      .to raise_error(ArgumentError, /no such question/)
  end

  it "refuses a rewrite that changes the rule's key or its handbook quote — the model may only rewrite, never invent" do
    allow(chat).to receive(:ask).and_return(reply("key" => "expense_other"))
    expect { described_class.call(rule: rule, ambiguity_index: 0, answer: "Ticket only") }
      .to raise_error(Assemble::AmbiguityResolver::InvalidRewrite, /key/)

    allow(chat).to receive(:ask).and_return(reply("source_quote" => "Something the handbook never said."))
    expect { described_class.call(rule: rule, ambiguity_index: 0, answer: "Ticket only") }
      .to raise_error(Assemble::AmbiguityResolver::InvalidRewrite, /quote/)

    expect(rule.reload.status).to eq("extracted")
  end
end
