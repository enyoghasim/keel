require "rails_helper"

RSpec.describe EvalResult, type: :model do
  it "records one outcome per case per run" do
    existing = create(:eval_result)

    expect(build(:eval_result, eval_run: existing.eval_run, eval_case: existing.eval_case)).not_to be_valid
  end
end
