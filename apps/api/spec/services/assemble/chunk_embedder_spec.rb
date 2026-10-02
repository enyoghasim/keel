require "rails_helper"

RSpec.describe Assemble::ChunkEmbedder do
  # The embedding call is mocked at the RubyLLM module boundary, same as
  # CsvMapper mocks RubyLLM::Chat — no network call, no API key needed.
  it "embeds every chunk's text in a single batched call and saves the vectors" do
    document = create(:source_document)
    first = create(:chunk, source_document: document, text: "First chunk.")
    second = create(:chunk, source_document: document, text: "Second chunk.")
    first_vector = Array.new(1536) { 0.1 }
    second_vector = Array.new(1536) { 0.2 }

    allow(RubyLLM).to receive(:embed)
      .with([ "First chunk.", "Second chunk." ])
      .and_return(instance_double(RubyLLM::Embedding, vectors: [ first_vector, second_vector ]))

    result = described_class.call(chunks: [ first, second ])

    expect(result).to eq([ first, second ])
    expect(first.reload.embedding).to eq(first_vector)
    expect(second.reload.embedding).to eq(second_vector)
  end

  it "does nothing for an empty list, without calling the LLM" do
    expect(RubyLLM).not_to receive(:embed)

    expect(described_class.call(chunks: [])).to eq([])
  end
end
