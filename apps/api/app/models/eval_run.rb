# One run of an eval suite against a company's vocabulary (SPEC.md
# section 12): which suite, which model, how many cases passed, and the
# per-case results.
class EvalRun < ApplicationRecord
  belongs_to :company
  belongs_to :person, optional: true
  has_many :eval_results, dependent: :destroy

  STATUSES = %w[pending running completed failed].freeze

  validates :suite, inclusion: { in: EvalCase::SUITES }
  validates :status, inclusion: { in: STATUSES }

  FIELDS = %i[id person_id suite status model cases_count passed_count started_at finished_at error_message created_at].freeze

  # Shared by Api::EvalRunsController and EvalChannel.
  def as_payload = as_json(only: FIELDS).merge("accuracy" => accuracy&.to_f)
end
