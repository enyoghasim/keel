class Policy < ApplicationRecord
  belongs_to :company
  has_many :rules, dependent: :destroy

  CATEGORIES = %w[leave expense remote equipment onboarding].freeze
  STATUSES = %w[draft active needs_review superseded].freeze

  validates :title, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :status, inclusion: { in: STATUSES }
end
