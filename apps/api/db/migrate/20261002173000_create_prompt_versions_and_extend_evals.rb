# Prompts live in the database so evals can compare versions (SPEC.md
# section 4 and 12), and eval runs/results gain the scores the Trust page
# shows beyond plain accuracy: per-case score and metrics, run-level
# stability, judge score and cost.
class CreatePromptVersionsAndExtendEvals < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_versions do |t|
      t.string :key, null: false
      t.integer :version, null: false
      t.text :template, null: false
      t.string :model
      t.boolean :active, null: false, default: false
      t.text :notes
      t.timestamps
    end
    add_index :prompt_versions, %i[key version], unique: true
    add_index :prompt_versions, :key, unique: true, where: "active", name: "index_prompt_versions_one_active_per_key"

    add_reference :eval_runs, :prompt_version, foreign_key: true, null: true
    add_column :eval_runs, :stability_samples, :integer, null: false, default: 0
    add_column :eval_runs, :stability, :decimal, precision: 5, scale: 4
    add_column :eval_runs, :judge_score, :decimal, precision: 4, scale: 2
    add_column :eval_runs, :cost_usd, :decimal, precision: 10, scale: 6

    add_column :eval_results, :score, :decimal, precision: 5, scale: 4
    add_column :eval_results, :metrics, :jsonb, null: false, default: {}
  end
end
