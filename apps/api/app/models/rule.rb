class Rule < ApplicationRecord
  belongs_to :policy
  belongs_to :source_chunk, class_name: "Chunk"
  has_many :rule_resolutions, dependent: :delete_all
  has_many :resulting_resolutions, class_name: "RuleResolution", foreign_key: :new_rule_id, inverse_of: :new_rule, dependent: :nullify

  STATUSES = %w[extracted resolved active superseded].freeze

  # What the engine and the policy page use: every version but the superseded ones.
  scope :current, -> { where.not(status: "superseded") }

  validates :key, :source_quote, presence: true
  validates :status, inclusion: { in: STATUSES }

  def to_rule_definition
    Rules::RuleDefinition.new(key: key, priority: priority, conditions: conditions, actions: actions)
  end
end
