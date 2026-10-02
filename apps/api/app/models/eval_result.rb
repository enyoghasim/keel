# One case's outcome within an EvalRun: pass/fail, what the model actually
# produced, and the field-level diff against what was expected.
class EvalResult < ApplicationRecord
  belongs_to :eval_run
  belongs_to :eval_case

  validates :eval_case_id, uniqueness: { scope: :eval_run_id }
end
