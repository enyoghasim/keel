# One "Describe a change" instruction on a workflow (SPEC.md section 8) and
# what became of it. Doubles as the trace (AGENTS.md rule 3): who asked for
# what, which model rewrote the workflow, and the ChangeProposal it produced
# — the model's output is never applied, only proposed.
class WorkflowEdit < ApplicationRecord
  belongs_to :company
  belongs_to :person
  belongs_to :workflow
  belongs_to :change_proposal, optional: true

  STATUSES = %w[pending proposed unchanged failed].freeze
  SOURCES = %w[instruction steps].freeze

  validates :instruction, presence: true, if: -> { source == "instruction" }
  validates :after_steps, presence: true, if: -> { source == "steps" }
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }

  FIELDS = %i[id workflow_id instruction source status change_proposal_id error_message created_at].freeze

  # The one shape Api::WorkflowEditsController renders and
  # WorkflowEditChannel broadcasts, so the page treats both the same.
  def as_payload = as_json(only: FIELDS)
end
