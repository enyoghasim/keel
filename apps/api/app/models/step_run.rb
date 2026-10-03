class StepRun < ApplicationRecord
  belongs_to :workflow_run
  belongs_to :resolved_person, class_name: "Person", optional: true

  EXTERNAL_STATUSES = %w[pending sent failed].freeze

  validates :step_key, presence: true
  validates :external_status, inclusion: { in: EXTERNAL_STATUSES }, allow_nil: true

  # What StepRunChannel broadcasts once a bound integration (Slack, Calendar)
  # resolves — the live side-effect state, not the step's approval status.
  def as_payload = as_json(only: %i[id step_key external_status external_ref external_error])
end
