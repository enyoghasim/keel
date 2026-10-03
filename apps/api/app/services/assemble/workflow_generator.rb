module Assemble
  # Stage 5 of the Assemble pipeline (SPEC.md section 6): the approval step
  # comes straight from the category's require_approval rules — Ruby keeps
  # the rules as the source of truth for who must approve, exactly as
  # Workflows::Runtime does at request time. The LLM only proposes the task
  # and notify steps around it (never an approval step — the schema
  # excludes that type entirely). Saved as a draft workflow.
  class WorkflowGenerator
    def self.call(company:, request_kind:, rules:)
      # strict: false — a step's title/when are ordinary optional properties,
      # but OpenAI's strict structured-output mode requires every property
      # to be listed in "required" and 400s otherwise.
      chat = RubyLLM.chat.with_schema(schema.merge("strict" => false))
      data = Llm::StructuredAsk.call(chat: chat, schema: schema, prompt: prompt(request_kind, rules))

      Workflow.create!(
        company: company, name: "#{request_kind.to_s.titleize} Workflow",
        trigger: { "request_kind" => request_kind.to_s },
        steps: [ approval_step_for(rules), *data.fetch("additional_steps") ].compact,
        status: "draft"
      )
    end

    def self.approval_step_for(rules)
      approver_refs = rules.filter_map { _1.actions["approvers"] if _1.actions["decision"] == "require_approval" }.flatten.uniq
      return nil if approver_refs.empty?

      { "key" => "approval", "type" => "approval", "assignee" => approver_refs.join(", ") }
    end
    private_class_method :approval_step_for

    def self.schema = Llm::SchemaRegistry.fetch("workflow-steps")
    private_class_method :schema

    def self.prompt(request_kind, rules)
      summary = rules.map { |r| "- #{r.key} (priority #{r.priority}): #{r.actions.to_json}" }.join("\n")

      <<~PROMPT
        Generate sensible task and notify steps — never approval; those come from the
        rules directly — for a #{request_kind} request workflow. Use role references
        like "role:it_admin" or org references like "manager_of(requester)" for each
        step's assignee, never a person's name.

        The policy's rules for this request kind:
        #{summary}
      PROMPT
    end
    private_class_method :prompt
  end
end
