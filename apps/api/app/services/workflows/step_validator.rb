module Workflows
  # Structural checks on a workflow's steps that the JSON schema can't
  # express (SPEC.md section 8): keys are unique, and every assignee is a
  # reference Org::Resolver can resolve — never a person's name (AGENTS.md
  # rule 1). Deterministic; returns the problems found, empty when valid.
  class StepValidator
    REFERENCE = /\A(requester|manager_of\(requester\)|skip_manager_of\(requester\)|head_of\(requester\.department\)|role:\w+|person:\d+)\z/

    def self.call(steps)
      duplicate_keys = steps.map { _1["key"] }.tally.select { |_key, count| count > 1 }.keys
      unknown = steps.reject { _1["assignee"].nil? || _1["assignee"].match?(REFERENCE) }

      duplicate_keys.map { "step key '#{_1}' is used more than once" } +
        unknown.map { "step '#{_1['key']}' has an unknown assignee reference '#{_1['assignee']}'" }
    end
  end
end
