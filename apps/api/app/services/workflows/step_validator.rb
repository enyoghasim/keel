module Workflows
  # Structural checks on a workflow's steps that the JSON schema can't
  # express (SPEC.md section 8): keys are unique, and every assignee is a
  # reference Org::Resolver can resolve — never a person's name (AGENTS.md
  # rule 1). Deterministic; returns the problems found, empty when valid.
  class StepValidator
    REFERENCE = /\A(requester|manager_of\(requester\)|skip_manager_of\(requester\)|head_of\(requester\.department\)|role:\w+|person:\d+)\z/

    def self.call(steps)
      duplicate_keys = steps.map { _1["key"] }.tally.select { |_key, count| count > 1 }.keys
      # An approval step's "assignee" is WorkflowGenerator's human-readable
      # join of every approver role (e.g. "manager_of(requester), role:finance_lead")
      # — Runtime resolves real approvers from the policy's decision, never
      # from this field, so it isn't a single reference to validate.
      unknown = steps.reject { _1["type"] == "approval" || _1["assignee"].nil? || _1["assignee"].match?(REFERENCE) }

      duplicate_keys.map { "step key '#{_1}' is used more than once" } +
        unknown.map { "step '#{_1['key']}' has an unknown assignee reference '#{_1['assignee']}'" }
    end

    # Approval steps are policy-owned (AGENTS.md rule 2): whoever is
    # rewriting a workflow — the AI "describe a change" path, or a human
    # editing it directly — never gets to add, remove or edit one. Any
    # approval step submitted is swapped for the original of the same key
    # (one invented is dropped); originals left out go back at their old
    # position.
    def self.restore_approvals(steps, current)
      originals = current.select { _1["type"] == "approval" }.index_by { _1["key"] }
      kept = steps.filter_map { |step| step["type"] == "approval" ? originals[step["key"]] : step }

      current.each_with_index do |step, index|
        kept.insert([ index, kept.size ].min, step) if step["type"] == "approval" && kept.none? { _1["key"] == step["key"] }
      end
      kept
    end
  end
end
