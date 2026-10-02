class Rule < ApplicationRecord
  belongs_to :policy
  belongs_to :source_chunk, class_name: "Chunk"

  STATUSES = %w[extracted resolved active superseded].freeze

  validates :key, :source_quote, presence: true
  validates :status, inclusion: { in: STATUSES }

  def to_rule_definition
    Rules::RuleDefinition.new(key: key, priority: priority, conditions: conditions, actions: actions)
  end
end
