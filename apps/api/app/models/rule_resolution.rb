# One answer to a rule's open question (SPEC.md section 7) and what became of
# it. Doubles as the trace (AGENTS.md rule 3): who answered what, which rule
# row it rewrote and which new version the model's rewrite became.
class RuleResolution < ApplicationRecord
  belongs_to :company
  belongs_to :person
  belongs_to :rule
  belongs_to :new_rule, class_name: "Rule", optional: true

  STATUSES = %w[pending resolved failed].freeze

  validates :answer, presence: true
  validates :status, inclusion: { in: STATUSES }

  # The one shape the controller renders and RuleResolutionChannel broadcasts.
  # Once resolved it carries both versions, so the page can draw the diff.
  def as_payload
    as_json(only: %i[id rule_id new_rule_id ambiguity_index answer status error_message created_at]).merge(
      "before" => rule_json(rule), "after" => new_rule && rule_json(new_rule)
    )
  end

  private

  def rule_json(record) = record.as_json(only: Api::RulesController::FIELDS)
end
