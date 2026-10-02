class CreateStepRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :step_runs do |t|
      t.references :workflow_run, null: false, foreign_key: true
      t.string :step_key, null: false
      t.string :reference
      t.references :resolved_person, foreign_key: { to_table: :people }
      t.string :status, null: false, default: "pending"
      t.datetime :acted_at
      t.boolean :overridden, null: false, default: false
      t.text :override_reason

      t.timestamps
    end
  end
end
