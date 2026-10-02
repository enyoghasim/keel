module Assemble
  # Stage 4 of the Assemble pipeline (SPEC.md section 6): retrieves the
  # chunks most relevant to a policy category, asks the LLM to extract
  # rules from them, and verifies every source_quote actually appears
  # verbatim in a provided chunk before persisting the rule — a hallucinated
  # quote gets the rule rejected and logged, never saved. Whitelisted
  # fields/operators/actions are enforced structurally by the
  # policy-rules schema.
  class PolicyExtractor
    Result = Data.define(:policy, :rules, :rejected)

    CATEGORY_QUERIES = {
      "leave" => "leave and time off policy",
      "expense" => "expense and reimbursement policy",
      "remote" => "remote work policy",
      "equipment" => "equipment and hardware policy",
      "onboarding" => "onboarding policy"
    }.freeze

    def self.call(company:, category:, chunks:)
      policy = Policy.create!(company: company, title: "#{category.to_s.titleize} Policy", category: category)
      chat = RubyLLM.chat.with_schema(schema)

      data = Llm::StructuredAsk.call(chat: chat, schema: schema, prompt: prompt(category, chunks))
      accepted, rejected = partition(data.fetch("rules"), chunks, policy)

      Result.new(policy: policy, rules: accepted, rejected: rejected)
    rescue Llm::StructuredAsk::ValidationError => e
      policy.update!(status: "needs_review")
      Rails.logger.warn("[Assemble::PolicyExtractor] #{category} extraction failed validation twice: #{e.message}")
      Result.new(policy: policy, rules: [], rejected: [])
    end

    def self.relevant_chunks_for(company:, category:, limit: 8)
      query_vector = RubyLLM.embed(CATEGORY_QUERIES.fetch(category.to_s)).vectors

      Chunk.joins(:source_document)
           .where(source_documents: { company_id: company.id })
           .nearest_neighbors(:embedding, query_vector, distance: "cosine")
           .first(limit)
    end

    def self.schema = Llm::SchemaRegistry.fetch("policy-rules")
    private_class_method :schema

    def self.partition(rules_data, chunks, policy)
      rules_data.each_with_object([ [], [] ]) do |rule_data, (accepted, rejected)|
        source_chunk = chunks.find { _1.text.include?(rule_data.fetch("source_quote")) }

        if source_chunk
          accepted << Rule.create!(
            policy: policy, key: rule_data.fetch("key"), priority: rule_data.fetch("priority"),
            conditions: rule_data.fetch("conditions"), actions: rule_data.fetch("actions"),
            source_chunk: source_chunk, source_quote: rule_data.fetch("source_quote"),
            ambiguities: rule_data.fetch("ambiguities")
          )
        else
          Rails.logger.warn("[Assemble::PolicyExtractor] rejected hallucinated source_quote: #{rule_data['source_quote'].inspect}")
          rejected << rule_data
        end
      end
    end
    private_class_method :partition

    def self.prompt(category, chunks)
      excerpt = chunks.each_with_index.map { |c, i| "Chunk #{i + 1} (page #{c.page}):\n#{c.text}" }.join("\n\n")

      <<~PROMPT
        Extract #{category} policy rules from the following handbook excerpts.
        Every rule's source_quote must be copied verbatim from one of these chunks — do
        not paraphrase it. Every vague phrase that needs a human decision must appear in
        that rule's ambiguities, with a question and options, rather than being guessed.

        #{excerpt}
      PROMPT
    end
    private_class_method :prompt
  end
end
