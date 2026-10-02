class CreateWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_runs do |t|
      t.references :request, null: false, foreign_key: true, index: { unique: true }
      t.references :workflow, foreign_key: true
      t.string :current_step
      t.string :status, null: false, default: "in_progress"

      t.timestamps
    end
  end
end
