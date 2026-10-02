require "rails_helper"

RSpec.describe Agent::Tools::SearchHandbook do
  # SPEC.md section 9: vector search over the handbook chunks, returning
  # quotes with page numbers — and degrading to keyword search when chunks
  # have no embeddings yet (seeded data) or no model is reachable.
  let(:company) { create(:company) }
  let(:asker) { create(:person, company: company) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }
  let(:document) { create(:source_document, company: company, filename: "nubo-handbook.pdf") }

  def call(args) = JSON.parse(tool.call(args))

  def basis(index) = Array.new(1536) { |i| i == index ? 1.0 : 0.0 }

  let!(:travel) { create(:chunk, source_document: document, page: 7, position: 1, text: "Flights and hotels for conferences are reimbursed up to €1,000.") }
  let!(:leave) { create(:chunk, source_document: document, page: 3, position: 2, text: "Employees get 24 days of annual leave, requested two weeks ahead.") }

  context "when chunks are embedded" do
    before do
      travel.update!(embedding: basis(0))
      leave.update!(embedding: basis(1))
      allow(Assemble::ChunkEmbedder).to receive(:available?).and_return(true)
      allow(RubyLLM).to receive(:embed).with("conference travel").and_return(instance_double(RubyLLM::Embedding, vectors: basis(0)))
    end

    it "returns the nearest chunks first, as quotes with page numbers" do
      result = call({ "query" => "conference travel" })

      expect(result["mode"]).to eq("semantic")
      expect(result["results"].first).to eq(
        "quote" => travel.text, "page" => 7, "document" => "nubo-handbook.pdf", "chunk_id" => travel.id
      )
      expect(result["results"].map { _1["page"] }).to eq([ 7, 3 ])
    end

    it "never returns another company's handbook" do
      create(:chunk, text: "Secret other-company text.", embedding: basis(0))

      expect(call({ "query" => "conference travel" })["results"].map { _1["quote"] }).not_to include("Secret other-company text.")
    end

    it "falls back to keyword search when the embedding call fails" do
      allow(RubyLLM).to receive(:embed).and_raise(RubyLLM::Error.new(nil, "boom"))

      result = call({ "query" => "annual leave" })

      expect(result["mode"]).to eq("keyword")
      expect(result["results"].first["page"]).to eq(3)
    end
  end

  context "when the handbook has no embeddings yet" do
    it "ranks chunks by how many of the query's words they contain, and says it used keywords" do
      result = call({ "query" => "how many days of annual leave" })

      expect(result["mode"]).to eq("keyword")
      expect(result["results"].map { _1["page"] }).to eq([ 3 ])
    end

    it "does not call the embedding model" do
      allow(RubyLLM).to receive(:embed)

      call({ "query" => "leave" })

      expect(RubyLLM).not_to have_received(:embed)
    end

    it "returns an empty list, not an error, when nothing matches" do
      expect(call({ "query" => "parking" })).to include("results" => [])
    end
  end
end
