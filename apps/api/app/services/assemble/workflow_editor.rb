module Assemble
  # Rewrites a workflow from a plain-English instruction (SPEC.md section 8,
  # "Describe a change"; the spec calls it Workflows::Generator, but
  # workflows/ is the no-LLM family — see apps/api/AGENTS.md). The model
  # returns the whole new workflow against the workflow-edit schema; Ruby
  # then keeps what isn't the model's to change. Approval steps are
  # whatever the policy rules say (AGENTS.md rule 2), so they are restored
  # verbatim whatever the model did to them, and every assignee must be a
  # reference, never a person's name (rule 1). Nothing is saved: the caller
  # computes the impact and records a ChangeProposal for a human to decide.
  class WorkflowEditor
    class InvalidWorkflow < StandardError; end

    Result = Data.define(:steps, :summary, :before) do
      def changed? = steps != before
    end

    def self.call(workflow:, instruction:)
      schema = Llm::SchemaRegistry.fetch("workflow-edit")
      data = Llm::StructuredAsk.call(chat: RubyLLM.chat.with_schema(schema), schema: schema, prompt: prompt(workflow, instruction))

      steps = restore_approvals(data.fetch("steps"), workflow.steps)
      errors = Workflows::StepValidator.call(steps)
      raise InvalidWorkflow, errors.join("; ") if errors.any?

      Result.new(steps: steps, summary: data.fetch("summary"), before: workflow.steps)
    end

    # Any approval step the model returns is swapped for the original of the
    # same key (one it invented is dropped); originals it left out go back
    # at their old position.
    def self.restore_approvals(steps, current)
      originals = current.select { _1["type"] == "approval" }.index_by { _1["key"] }
      kept = steps.filter_map { |step| step["type"] == "approval" ? originals[step["key"]] : step }

      current.each_with_index do |step, index|
        kept.insert([ index, kept.size ].min, step) if step["type"] == "approval" && kept.none? { _1["key"] == step["key"] }
      end
      kept
    end
    private_class_method :restore_approvals

    def self.prompt(workflow, instruction)
      <<~PROMPT
        Here is a company workflow for #{workflow.trigger['request_kind']} requests, as JSON — its steps run in order:

        #{workflow.steps.to_json}

        Apply this change request: #{instruction}

        Return the complete new workflow: every step in order, including the existing approval
        step(s) exactly as they are. Approval steps are decided by company policy, so never add,
        remove or edit one. Use a "task" step for work someone must do and a "notify" step for
        a heads-up. Give each step a short unique snake_case key and a role reference like
        "role:it_admin" or an org reference like "manager_of(requester)" as its assignee —
        never a person's name. To make a step conditional, add a "when" condition. Keep every
        step you aren't asked to change as it is.
      PROMPT
    end
    private_class_method :prompt
  end
end
