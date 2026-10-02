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
