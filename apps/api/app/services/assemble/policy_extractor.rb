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

    PROMPT_KEY = "policy_extractor".freeze

    # The prompt used when no version is active in the database. Placeholders
    # are filled by PromptVersion#render, same as a stored version.
    DEFAULT_TEMPLATE = <<~PROMPT.freeze
      Extract {{category}} policy rules from the following handbook excerpts.
      Every rule's source_quote must be copied verbatim from one of these chunks — do
      not paraphrase it. Every vague phrase that needs a human decision must appear in
      that rule's ambiguities, with a question and options, rather than being guessed.

      Only use a payload.category condition when extracting expense or equipment rules,
      where the handbook names real categories (travel, laptop, general, ...). Never add
      one for leave, remote or onboarding rules — those requests carry no category field,
      so a condition on it can never match. A rule also never needs to check that it's
      being evaluated for the right category: that's already guaranteed by which policy
      it belongs to, before the rule's own conditions are even considered. Likewise, when
      a sentence states a default or baseline threshold without naming a specific category
      (e.g. "expenses of €400 or less are approved automatically"), don't add a category
      condition to it at all — it's meant to apply across categories, with more specific
      rules (travel, equipment, ...) overriding it by priority, not by a narrower category
      match you invent.

      When an action is require_approval, write each approver in its approvers array as a
      reference, never a plain-English role or job title: "manager_of(requester)" for the
      requester's manager, "role:finance_lead"/"role:it_admin"/"role:hr_admin" for a named
      role, "head_of(requester.department)" for the department head. Never write "manager",
      "finance lead", "HR" or any other plain word there — the engine only resolves these
      exact reference forms, so anything else silently fails to route to anyone.

      A condition must be exactly as narrow as the quote supports, no narrower and no
      broader. "Alcohol is never reimbursed" means a rule scoped to the alcohol category,
      not one that rejects every expense; a vague carve-out you can't turn into a precise
      condition (e.g. "warehouse roles are always on site") belongs in ambiguities instead
      of a guessed condition that changes what other, unrelated requests do.

      {{excerpt}}
    PROMPT

    def self.call(company:, category:, chunks:)
      policy = Policy.create!(company: company, title: "#{category.to_s.titleize} Policy", category: category)

      rules_data = compile(category: category, chunks: chunks)
      accepted, rejected = partition(rules_data, chunks, policy)

      Result.new(policy: policy, rules: accepted, rejected: rejected)
    rescue Llm::StructuredAsk::ValidationError => e
      policy.update!(status: "needs_review")
      Rails.logger.warn("[Assemble::PolicyExtractor] #{category} extraction failed validation twice: #{e.message}")
      Result.new(policy: policy, rules: [], rejected: [])
    end

    # The LLM half on its own: asks the model (with the given prompt
    # version, else the active one, else the built-in template) and returns
    # the schema-validated rules, saving nothing. Raises
    # Llm::StructuredAsk::ValidationError if the output is invalid twice.
    # Chunks need only respond to #page and #text, so evals can compile a
    # passage that isn't a stored Chunk. A block receives what each model
    # call cost (see Llm::StructuredAsk).
    def self.compile(category:, chunks:, prompt_version: PromptVersion.active_for(PROMPT_KEY), &on_cost)
      template = prompt_version ? prompt_version : PromptVersion.new(template: DEFAULT_TEMPLATE)
      chat = RubyLLM.chat.with_schema(schema)

      Llm::StructuredAsk.call(chat: chat, schema: schema, prompt: template.render(category: category, excerpt: excerpt(chunks)), &on_cost).fetch("rules")
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

    def self.excerpt(chunks)
      chunks.each_with_index.map { |c, i| "Chunk #{i + 1} (page #{c.page}):\n#{c.text}" }.join("\n\n")
    end
    private_class_method :excerpt
  end
end
