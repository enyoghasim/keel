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

  # The last `limit` answered messages of this run's conversation that came
  # before it, oldest first — what the agent replays as earlier turns.
  def previous_turns(limit)
    AgentRun.where(person_id: person_id, conversation_id: conversation_id, status: "completed")
      .where("created_at < :at OR (created_at = :at AND id < :id)", at: created_at, id: id)
      .order(created_at: :desc, id: :desc).limit(limit).reverse
  end

  FIELDS = %i[id conversation_id person_id message status final_text total_tokens error_message created_at].freeze

  # Shared by Api::AgentRunsController and AgentChannel.
  def as_payload = as_json(only: FIELDS).merge("steps" => agent_steps.map(&:as_payload))
end
