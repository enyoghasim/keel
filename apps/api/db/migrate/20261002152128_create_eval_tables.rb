class CreateEvalTables < ActiveRecord::Migration[8.1]
  def change
    create_table :eval_cases do |t|
      t.string :suite, null: false
      t.string :key, null: false
      t.jsonb :input, null: false, default: {}
      t.jsonb :expected, null: false, default: {}
      t.string :source, null: false, default: "manual"
      t.string :status, null: false, default: "active"
      t.text :notes

      t.timestamps
    end
    add_index :eval_cases, %i[suite key], unique: true

    create_table :eval_runs do |t|
      t.references :company, null: false, foreign_key: true
      t.references :person, null: true, foreign_key: true
      t.string :suite, null: false
      t.string :status, null: false, default: "pending"
      t.string :model
      t.decimal :accuracy, precision: 5, scale: 4
      t.integer :cases_count, null: false, default: 0
      t.integer :passed_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end

    create_table :eval_results do |t|
      t.references :eval_run, null: false, foreign_key: true
      t.references :eval_case, null: false, foreign_key: true
      t.boolean :passed, null: false, default: false
      t.jsonb :actual
      t.jsonb :diff, null: false, default: []
      t.integer :latency_ms
      t.text :error_message

      t.timestamps
    end
    add_index :eval_results, %i[eval_run_id eval_case_id], unique: true
  end
end
