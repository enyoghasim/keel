# One test case in an eval suite (SPEC.md section 12): an input, the
# expected output, and where it came from. Candidates are proposed by
# production signals (overrides, thumbs-down, rejected proposals) and only
# join a suite's runs once a reviewer makes them active.
class EvalCase < ApplicationRecord
  has_many :eval_results, dependent: :destroy

  SUITES = %w[policy_extraction agent insights].freeze
  SOURCES = %w[manual generated override].freeze
  STATUSES = %w[active candidate archived].freeze

  validates :key, presence: true, uniqueness: { scope: :suite }
  validates :suite, inclusion: { in: SUITES }
  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
end
