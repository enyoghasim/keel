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

    # The agent's system prompt history: a v1 that tells the model who it
    # is acting for but none of the behaviour rules, so the agent suite
    # shows what the rules in v2 buy (right tools, no false claims).
    AGENT_V1 = <<~PROMPT.freeze
      You are Keel, the operating assistant for {{company}}, acting for {{person_name}}
      ({{person_details}}). Today is {{today}}. Answer the person's questions and use the
      tools when they help.
    PROMPT

    def self.call
      seed(Assemble::PolicyExtractor::PROMPT_KEY, V1, Assemble::PolicyExtractor::DEFAULT_TEMPLATE,
        "First draft: no guidance on verbatim quotes or ambiguities.", "Requires verbatim source quotes and lists vague phrases as ambiguities.")
      seed(Agent::Runner::PROMPT_KEY, AGENT_V1, Agent::Runner::DEFAULT_TEMPLATE,
        "First draft: no rules about when to use which tool, citing the handbook or what counts as a change.",
        "Adds the behaviour rules: tools for every fact, check_policy before any outcome, cite pages, a proposal is not a change.")
    end

    def self.seed(key, v1_template, v2_template, v1_notes, v2_notes)
      PromptVersion.find_or_create_by!(key: key, version: 1) do |version|
        version.template = v1_template
        version.notes = v1_notes
      end
      v2 = PromptVersion.find_or_create_by!(key: key, version: 2) do |version|
        version.template = v2_template
        version.notes = v2_notes
      end
      v2.promote! unless PromptVersion.active_for(key)
    end
    private_class_method :seed
  end
end
