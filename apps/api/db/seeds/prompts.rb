module Seeds
  # The policy extractor's prompt history (SPEC.md section 12's demo): a
  # deliberately weak v1 — no instruction to quote verbatim, no ambiguity
  # guidance — and the stronger v2 that's active. Running the policy
  # extraction suite against each shows a real, explainable difference.
  # Idempotent: existing versions are left as they are.
  module Prompts
    V1 = <<~PROMPT.freeze
      Extract {{category}} policy rules from the following handbook excerpts.

      {{excerpt}}
    PROMPT

    def self.call
      PromptVersion.find_or_create_by!(key: Assemble::PolicyExtractor::PROMPT_KEY, version: 1) do |version|
        version.template = V1
        version.notes = "First draft: no guidance on verbatim quotes or ambiguities."
      end
      v2 = PromptVersion.find_or_create_by!(key: Assemble::PolicyExtractor::PROMPT_KEY, version: 2) do |version|
        version.template = Assemble::PolicyExtractor::DEFAULT_TEMPLATE
        version.notes = "Requires verbatim source quotes and lists vague phrases as ambiguities."
      end
      v2.promote! unless PromptVersion.active_for(Assemble::PolicyExtractor::PROMPT_KEY)
    end
  end
end
