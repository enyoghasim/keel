# One message to the agent and everything it did about it (SPEC.md section
# 9): who asked, the final answer, token totals, and every model call and
# tool call as an ordered AgentStep — the trace AGENTS.md rule 3 requires.
class AgentRun < ApplicationRecord
  belongs_to :company
  belongs_to :person
  has_many :agent_steps, -> { order(:position) }, dependent: :destroy, inverse_of: :agent_run

  STATUSES = %w[pending running completed failed].freeze

  validates :message, presence: true
  validates :status, inclusion: { in: STATUSES }

  FIELDS = %i[id person_id message status final_text total_tokens error_message created_at].freeze

  # Shared by Api::AgentRunsController and AgentChannel.
  def as_payload = as_json(only: FIELDS).merge("steps" => agent_steps.map(&:as_payload))
end
