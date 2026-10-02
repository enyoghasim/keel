require "rails_helper"

RSpec.describe Llm::StructuredAsk do
  # Shared by every AI service that calls the LLM with a JSON Schema
  # (apps/api/AGENTS.md: validate against packages/schemas, retry once with
  # the errors appended, then give up) — factored out of Assemble::CsvMapper
  # so Assemble::PolicyExtractor doesn't duplicate the retry loop.
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:schema) do
    { "type" => "object", "required" => [ "ok" ], "additionalProperties" => false, "properties" => { "ok" => { "type" => "boolean" } } }
  end

  def message_with(content) = instance_double(RubyLLM::Message, content: content)

  it "returns the response content once it passes schema validation" do
    allow(chat).to receive(:ask).and_return(message_with({ "ok" => true }))

    result = described_class.call(chat: chat, schema: schema, prompt: "go")

    expect(result).to eq({ "ok" => true })
  end

  it "retries once with the validation errors appended, then returns the corrected content" do
    allow(chat).to receive(:ask).and_return(message_with({ "ok" => "not a boolean" }), message_with({ "ok" => true }))

    result = described_class.call(chat: chat, schema: schema, prompt: "go")

    expect(result).to eq({ "ok" => true })
    expect(chat).to have_received(:ask).twice
    expect(chat).to have_received(:ask).with(a_string_including("failed validation"))
  end

  it "raises after exhausting retries instead of retrying forever" do
    allow(chat).to receive(:ask).and_return(message_with({ "ok" => "nope" }), message_with({ "ok" => "still nope" }))

    expect { described_class.call(chat: chat, schema: schema, prompt: "go") }
      .to raise_error(Llm::StructuredAsk::ValidationError)
    expect(chat).to have_received(:ask).twice
  end

  describe "reporting cost" do
    # `cost` is what ruby_llm priced the message at: nil for a model it has no rates for.
    def priced(content, cost: 1.25) = instance_double(RubyLLM::Message, content: content, cost: instance_double(RubyLLM::Cost, total: cost))

    it "hands each attempt's cost to the block, retries included" do
      allow(chat).to receive(:ask).and_return(priced({ "ok" => "nope" }), priced({ "ok" => true }))
      costs = []

      described_class.call(chat: chat, schema: schema, prompt: "go") { costs << _1 }

      expect(costs).to eq([ 1.25, 1.25 ])
    end

    it "reports nothing for a model it has no pricing for" do
      allow(chat).to receive(:ask).and_return(priced({ "ok" => true }, cost: nil))
      costs = []

      described_class.call(chat: chat, schema: schema, prompt: "go") { costs << _1 }

      expect(costs).to eq([])
    end
  end
end
