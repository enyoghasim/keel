require "rails_helper"

RSpec.describe Assemble::PolicyExtractor do
  # Mirrors SPEC.md section 6, stage 4 and its three hard requirements: the
  # source_quote hallucination check matters most, so it gets its own
  # examples rather than being folded into the happy path.
  let(:chat) { instance_double(RubyLLM::Chat) }

  def message_with(content) = instance_double(RubyLLM::Message, content: content)

  before { allow(RubyLLM).to receive(:chat).and_return(chat) }

  describe ".call" do
    before { allow(chat).to receive(:with_schema).and_return(chat) }

    it "creates a draft policy and persists a rule whose source_quote is verified against a chunk" do
      company = create(:company)
      document = create(:source_document, company: company)
      chunk = create(:chunk, source_document: document, page: 4,
        text: "Engineers attending conferences are automatically approved up to €1,000.")
      valid_response = {
        "rules" => [
          {
            "key" => "expense_conference_engineering", "priority" => 10,
            "conditions" => { "all" => [
              { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
              { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 }
            ] },
            "actions" => { "decision" => "auto_approve" },
            "source_quote" => "Engineers attending conferences are automatically approved up to €1,000.",
            "ambiguities" => []
          }
        ]
      }
      allow(chat).to receive(:ask).and_return(message_with(valid_response))

      result = described_class.call(company: company, category: "expense", chunks: [ chunk ])

      expect(result.policy).to have_attributes(company: company, category: "expense", status: "draft")
      expect(result.rules.size).to eq(1)
      rule = result.rules.first
      expect(rule).to have_attributes(key: "expense_conference_engineering", source_chunk: chunk, policy: result.policy)
      expect(result.rejected).to eq([])
    end

    it "rejects a rule whose source_quote doesn't verbatim-appear in any provided chunk" do
      company = create(:company)
      document = create(:source_document, company: company)
      chunk = create(:chunk, source_document: document, text: "Expenses under €500 are auto-approved.")
      hallucinated_response = {
        "rules" => [
          {
            "key" => "made_up_rule", "priority" => 1,
            "conditions" => { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
            "actions" => { "decision" => "auto_approve" },
            "source_quote" => "This sentence does not appear anywhere in the handbook.",
            "ambiguities" => []
          }
        ]
      }
      allow(chat).to receive(:ask).and_return(message_with(hallucinated_response))

      result = described_class.call(company: company, category: "expense", chunks: [ chunk ])

      expect(result.rules).to eq([])
      expect(Rule.count).to eq(0)
      expect(result.rejected.size).to eq(1)
      expect(result.rejected.first["key"]).to eq("made_up_rule")
      expect(result.policy.status).to eq("draft")
    end

    it "marks the policy needs_review when the LLM's output still fails validation after a retry" do
      company = create(:company)
      document = create(:source_document, company: company)
      chunk = create(:chunk, source_document: document)
      invalid_response = { "rules" => [ { "key" => "x" } ] }
      allow(chat).to receive(:ask).and_return(message_with(invalid_response), message_with(invalid_response))

      result = described_class.call(company: company, category: "expense", chunks: [ chunk ])

      expect(result.policy.status).to eq("needs_review")
      expect(result.rules).to eq([])
    end
  end

  describe ".compile" do
    # The LLM half on its own — no policy or rule is saved — so the eval
    # harness can compile a passage with any prompt version.
    let(:passage) { Struct.new(:page, :text).new(4, "Expenses under €500 are auto-approved.") }
    let(:response) { { "rules" => [] } }

    before do
      allow(chat).to receive(:with_schema).and_return(chat)
      allow(chat).to receive(:ask).and_return(message_with(response))
    end

    it "returns the schema-validated rules without persisting anything" do
      rule = {
        "key" => "small", "priority" => 1, "conditions" => { "field" => "payload.amount_eur", "op" => "lt", "value" => 500 },
        "actions" => { "decision" => "auto_approve" }, "source_quote" => passage.text, "ambiguities" => []
      }
      allow(chat).to receive(:ask).and_return(message_with({ "rules" => [ rule ] }))

      expect(described_class.compile(category: "expense", chunks: [ passage ])).to eq([ rule ])
      expect(Policy.count).to eq(0)
    end

    it "fills the given prompt version's template with the category and the chunks, page by page" do
      version = build(:prompt_version, template: "CUSTOM {{category}} PROMPT\n{{excerpt}}")

      described_class.compile(category: "expense", chunks: [ passage ], prompt_version: version)

      expect(chat).to have_received(:ask).with(a_string_starting_with("CUSTOM expense PROMPT").and(including("Chunk 1 (page 4)", passage.text)))
    end

    it "uses the active prompt version of key policy_extractor when none is given" do
      create(:prompt_version, key: "policy_extractor", version: 2, active: true, template: "ACTIVE {{category}}\n{{excerpt}}")

      described_class.compile(category: "leave", chunks: [ passage ])

      expect(chat).to have_received(:ask).with(a_string_starting_with("ACTIVE leave"))
    end

    it "falls back to the built-in template, which insists on verbatim quotes, when no version is active" do
      described_class.compile(category: "leave", chunks: [ passage ])

      expect(chat).to have_received(:ask).with(a_string_including("verbatim"))
    end
  end

  describe ".relevant_chunks_for" do
    it "returns the company's chunks ordered by similarity to the category's query embedding" do
      company = create(:company)
      other_company = create(:company)
      document = create(:source_document, company: company)
      other_document = create(:source_document, company: other_company)
      origin = Array.new(1536, 0.0)
      close = create(:chunk, source_document: document, embedding: [ 0.1 ] + origin[1..])
      far = create(:chunk, source_document: document, embedding: [ 10.0 ] + origin[1..])
      create(:chunk, source_document: other_document, embedding: [ 0.05 ] + origin[1..])

      allow(RubyLLM).to receive(:embed).with("expense and reimbursement policy").and_return(instance_double(RubyLLM::Embedding, vectors: origin))

      result = described_class.relevant_chunks_for(company: company, category: "expense")

      expect(result).to eq([ close, far ])
    end
  end
end
