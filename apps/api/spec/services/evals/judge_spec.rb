require "rails_helper"

RSpec.describe Evals::Judge do
  # SPEC.md section 12: a separate model call grades the agent's final
  # answer against a rubric, seeing the tool outputs so it grades
  # faithfulness to them rather than general knowledge.
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:judgement) { { "correctness" => 5, "citation" => 4, "clarity" => 5, "no_false_claims" => 3, "rationale" => "It said the request was filed." } }
  let(:tool_calls) { [ { "name" => "check_policy", "input" => { "request_kind" => "expense" }, "output" => { "decision" => "require_approval" } } ] }

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: judgement))
  end

  it "returns the four rubric scores, their mean and the rationale" do
    result = described_class.call(message: "Can I expense €1,200?", tool_calls: tool_calls, answer: "Yes, a manager approves it.")

    expect(result.scores).to eq("correctness" => 5, "citation" => 4, "clarity" => 5, "no_false_claims" => 3)
    expect(result.mean).to eq(4.25)
    expect(result.rationale).to eq("It said the request was filed.")
  end

  it "shows the judge the question, the tool outputs and the answer, so it grades faithfulness" do
    described_class.call(message: "Can I expense €1,200?", tool_calls: tool_calls, answer: "Yes, a manager approves it.")

    expect(chat).to have_received(:ask).with(a_string_including("Can I expense €1,200?", "check_policy", "require_approval", "Yes, a manager approves it.", "correctness"))
  end

  it "retries once when the judge's output fails the schema, then raises" do
    allow(chat).to receive(:ask).and_return(instance_double(RubyLLM::Message, content: { "correctness" => 9 }))

    expect { described_class.call(message: "x", tool_calls: [], answer: "y") }.to raise_error(Llm::StructuredAsk::ValidationError)
    expect(chat).to have_received(:ask).twice
  end

  describe ".agreement" do
    it "is the share of rubric dimensions where the judge is within one point of a hand label" do
      scores = { "correctness" => 5, "citation" => 3, "clarity" => 4, "no_false_claims" => 1 }
      label = { "correctness" => 5, "citation" => 5, "clarity" => 3, "no_false_claims" => 1 }

      expect(described_class.agreement(scores, label)).to eq(0.75)
    end
  end
end
