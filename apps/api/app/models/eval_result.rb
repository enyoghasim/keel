# One case's outcome within an EvalRun: pass/fail, what the model actually
# produced, and the field-level diff against what was expected.
class EvalResult < ApplicationRecord
  belongs_to :eval_run
  belongs_to :eval_case

  validates :eval_case_id, uniqueness: { scope: :eval_run_id }

  FIELDS = %i[id eval_case_id passed actual diff latency_ms error_message].freeze

  # Carries the case's key, input and expected output alongside the
  # outcome, so a failure can be drilled into without a second request.
  def as_payload
    as_json(only: FIELDS).merge(
      "case_key" => eval_case.key, "input" => eval_case.input, "expected" => eval_case.expected
    )
  end
end
