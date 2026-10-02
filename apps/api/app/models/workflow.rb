class Workflow < ApplicationRecord
  belongs_to :company
  has_many :workflow_runs, dependent: :restrict_with_error

  STATUSES = %w[draft active superseded].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
end
