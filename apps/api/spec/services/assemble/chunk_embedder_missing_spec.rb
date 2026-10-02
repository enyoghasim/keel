require "rails_helper"

RSpec.describe Assemble::ChunkEmbedder, ".embed_missing" do
  # Seeded handbooks have no embeddings (seeding must not need a model
  # key); this fills them in later, e.g. from `rake handbook:embed`.
  let(:document) { create(:source_document) }
  let(:vector) { Array.new(1536) { 0.1 } }

  before { allow(described_class).to receive(:available?).and_return(true) }

  def stub_embed(count = 1)
    allow(RubyLLM).to receive(:embed).and_return(instance_double(RubyLLM::Embedding, vectors: Array.new(count) { vector }))
  end

  it "embeds only the chunks that have no embedding yet and returns how many it did" do
    done = create(:chunk, source_document: document, embedding: Array.new(1536) { 0.5 })
    todo = create(:chunk, source_document: document)
    stub_embed

    expect(described_class.embed_missing).to eq(1)

    expect(RubyLLM).to have_received(:embed).with([ todo.text ])
    expect(todo.reload.embedding).to eq(vector)
    expect(done.reload.embedding.first).to eq(0.5)
  end

  it "batches the calls" do
    create_list(:chunk, 3, source_document: document)
    stub_embed(2)
    allow(RubyLLM).to receive(:embed).and_return(
      instance_double(RubyLLM::Embedding, vectors: [ vector, vector ]), instance_double(RubyLLM::Embedding, vectors: [ vector ])
    )

    expect(described_class.embed_missing(batch_size: 2)).to eq(3)
    expect(RubyLLM).to have_received(:embed).twice
  end

  it "can be limited to one company" do
    mine = create(:chunk, source_document: create(:source_document, company: document.company))
    other = create(:chunk)
    stub_embed

    described_class.embed_missing(company: document.company)

    expect(mine.reload.embedding).to be_present
    expect(other.reload.embedding).to be_nil
  end

  it "does nothing, without calling the model, when no embedding model is configured" do
    create(:chunk, source_document: document)
    allow(described_class).to receive(:available?).and_return(false)

    expect(described_class.embed_missing).to eq(0)
  end

  describe ".available?" do
    around do |example|
      key, base = RubyLLM.config.openai_api_key, RubyLLM.config.openai_api_base
      example.run
    ensure
      RubyLLM.configure { |c| c.openai_api_key = key; c.openai_api_base = base }
    end

    before { allow(described_class).to receive(:available?).and_call_original }

    it "is true with an OpenAI key or a custom API base, false with neither" do
      RubyLLM.configure { |c| c.openai_api_key = nil; c.openai_api_base = nil }
      expect(described_class.available?).to be(false)
      RubyLLM.configure { |c| c.openai_api_key = "sk-test" }
      expect(described_class.available?).to be(true)
      RubyLLM.configure { |c| c.openai_api_key = nil; c.openai_api_base = "http://localhost:9999/v1" }
      expect(described_class.available?).to be(true)
    end
  end
end
