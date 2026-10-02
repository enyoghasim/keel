class AddJudgeAgreementToEvalRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :eval_runs, :judge_agreement, :decimal, precision: 5, scale: 4
  end
end
