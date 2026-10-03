# A company's connection to an external service (Slack, Google Calendar),
# used by workflow steps bound to it (StepSideEffectJob). Credentials —
# a Slack webhook URL, or Calendar OAuth tokens — are encrypted at rest;
# see config/initializers/active_record_encryption.rb.
class Integration < ApplicationRecord
  belongs_to :company

  KINDS = %w[slack google_calendar].freeze
  STATUSES = %w[disconnected connected error].freeze

  attribute :credentials, ActiveRecord::Type::Json.new
  encrypts :credentials

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :company_id, uniqueness: { scope: :kind }
end
