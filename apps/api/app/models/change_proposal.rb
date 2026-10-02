class ChangeProposal < ApplicationRecord
  belongs_to :company
  belongs_to :decided_by, class_name: "Person", optional: true
  # The trace this proposal came from, when the agent proposed it (AGENTS.md rule 3).
  belongs_to :agent_run, optional: true

  KINDS = %w[org rule workflow].freeze
  STATUSES = %w[pending approved rejected].freeze
  PROPOSED_BY_VALUES = %w[agent user].freeze

  validates :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :proposed_by, inclusion: { in: PROPOSED_BY_VALUES }

  class StaleDiff < StandardError; end

  # The "after" rules of a rule proposal as engine input, keyed by rule key.
  def after_rule_definitions
    diff.fetch("after").to_h do |rule|
      [ rule["key"], Rules::RuleDefinition.new(key: rule["key"], priority: rule["priority"], conditions: rule["conditions"], actions: rule["actions"]) ]
    end
  end

  # Applies a rule proposal (SPEC.md section 10): each rewritten rule's
  # current version is superseded and replaced by a new active one that
  # keeps the original handbook source, and the policy's version is bumped.
  # Refuses with StaleDiff if the rules it was computed against have since
  # changed, so a proposal never overwrites someone else's edit.
  def apply_rule_diff!(company)
    policy = company.policies.find(diff.fetch("policy_id"))

    transaction do
      diff.fetch("before").each do |before|
        current = policy.rules.find_by(key: before["key"], status: "active")
        unless current && current.conditions == before["conditions"] && current.actions == before["actions"] && current.priority == before["priority"]
          raise StaleDiff, "rule #{before['key']} has changed since this proposal was made"
        end

        after = diff.fetch("after").find { _1["key"] == before["key"] }
        current.update!(status: "superseded")
        policy.rules.create!(
          key: current.key, priority: after["priority"], conditions: after["conditions"], actions: after["actions"],
          source_chunk: current.source_chunk, source_quote: current.source_quote, ambiguities: current.ambiguities, status: "active"
        )
      end
      policy.update!(version: policy.version + 1)
    end
  end

  # Applies this proposal's org diff to the real Person/Department records
  # (SPEC.md section 10) — mirrors Org::GraphSnapshot#apply!, but against
  # the company's live rows instead of a dry-run snapshot copy.
  def apply_org_diff!(company)
    diff.each do |op|
      case op["op"]
      when "change_manager"
        company.people.find(op["person_id"]).update!(manager_id: op["to"])
      when "move_person"
        company.people.find(op["person_id"]).update!(department_id: company.departments.find(op["department_id"]).id)
      when "set_department_head"
        company.departments.find(op["department_id"]).update!(head_id: op["to"])
      when "assign_role"
        person = company.people.find(op["person_id"])
        person.update!(roles: (person.roles + [ op["role"] ]).uniq)
      else
        raise ArgumentError, "unknown diff operation #{op["op"]}"
      end
    end
  end
end
