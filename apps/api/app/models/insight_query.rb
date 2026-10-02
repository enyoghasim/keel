# One natural-language analytics question and how Keel understood it
# (SPEC.md section 11). Doubles as its trace (AGENTS.md rule 3): the
# question, the query object Insights::Interpreter produced (or its
# clarifying question), the model that produced it, and the rows
# Insights::QueryBuilder computed from it.
class InsightQuery < ApplicationRecord
  belongs_to :company
  belongs_to :person

  STATUSES = %w[pending answered needs_clarification failed].freeze

  validates :question, presence: true
  validates :status, inclusion: { in: STATUSES }

  FIELDS = %i[id person_id question status query clarification result error_message created_at].freeze

  # The one shape Api::InsightsController renders and InsightChannel
  # broadcasts, so the page treats both the same.
  def as_payload = as_json(only: FIELDS)
end
