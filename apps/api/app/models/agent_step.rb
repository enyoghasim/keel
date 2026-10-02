# One step of an AgentRun's trace: a model call (kind "llm", with tokens
# and the tool calls it asked for) or a tool call (kind "tool", with its
# input and output). Ordered by position.
class AgentStep < ApplicationRecord
  belongs_to :agent_run

  KINDS = %w[llm tool].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :position, presence: true, uniqueness: { scope: :agent_run_id }

  FIELDS = %i[id position kind tool_name input output latency_ms tokens].freeze

  def as_payload = as_json(only: FIELDS)
end
