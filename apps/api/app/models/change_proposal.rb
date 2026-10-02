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

  # Applies this proposal's org diff to the real Person/Department records
  # (SPEC.md section 10) — mirrors Org::GraphSnapshot#apply!, but against
  # the company's live rows instead of a dry-run snapshot copy.
  def apply_org_diff!(company)
    diff.each do |op|
      case op["op"]
      when "change_manager"
        company.people.find(op["person_id"]).update!(manager_id: op["to"])
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
