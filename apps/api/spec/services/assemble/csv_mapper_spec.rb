require "rails_helper"

RSpec.describe Assemble::CsvMapper do
  # The LLM boundary is mocked at the RubyLLM::Chat interface — these specs
  # never make a network call, per apps/api/AGENTS.md's deterministic/AI
  # split: the AI service's own wiring is what's under test here, not a
  # real model's behavior.
  let(:chat) { instance_double(RubyLLM::Chat) }

  def message_with(content) = instance_double(RubyLLM::Message, content: content)

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
  end

  it "maps CSV headers to Keel fields from the LLM's schema-validated response" do
    valid_response = {
      "mappings" => [
        { "source_column" => "Full Name", "field" => "name", "confidence" => 0.98 },
        { "source_column" => "E-mail", "field" => "email", "confidence" => 0.99 },
        { "source_column" => "Badge #", "field" => "ignore", "confidence" => 0.9 }
      ]
    }
    allow(chat).to receive(:ask).and_return(message_with(valid_response))

    mappings = described_class.call(headers: [ "Full Name", "E-mail", "Badge #" ], sample_rows: [ [ "Ada Nwosu", "ada@factorial.example", "117" ] ])

    expect(mappings).to contain_exactly(
      Assemble::CsvMapper::Mapping.new("Full Name", "name", 0.98),
      Assemble::CsvMapper::Mapping.new("E-mail", "email", 0.99),
      Assemble::CsvMapper::Mapping.new("Badge #", "ignore", 0.9)
    )
  end

  it "retries once, appending the validation error, when the first response fails the schema" do
    invalid_response = { "mappings" => [ { "source_column" => "Grp", "field" => "team", "confidence" => 0.5 } ] }
    valid_response = { "mappings" => [ { "source_column" => "Grp", "field" => "department", "confidence" => 0.55 } ] }
    allow(chat).to receive(:ask).and_return(message_with(invalid_response), message_with(valid_response))

    mappings = described_class.call(headers: [ "Grp" ], sample_rows: [ [ "Engineering" ] ])

    expect(mappings).to contain_exactly(Assemble::CsvMapper::Mapping.new("Grp", "department", 0.55))
    expect(chat).to have_received(:ask).twice
    expect(chat).to have_received(:ask).with(a_string_including("failed validation"))
  end

  it "raises after a second invalid response instead of retrying forever" do
    invalid_response = { "mappings" => [ { "source_column" => "Grp", "field" => "team", "confidence" => 0.5 } ] }
    allow(chat).to receive(:ask).and_return(message_with(invalid_response), message_with(invalid_response))

    expect { described_class.call(headers: [ "Grp" ], sample_rows: [ [ "Engineering" ] ]) }
      .to raise_error(Assemble::CsvMapper::ValidationError)
    expect(chat).to have_received(:ask).twice
  end
end
