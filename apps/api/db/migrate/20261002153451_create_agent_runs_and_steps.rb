class CreateAgentRunsAndSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_runs do |t|
      t.references :company, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.text :message, null: false
      t.string :status, null: false, default: "pending"
      t.text :final_text
      t.integer :total_tokens, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    create_table :agent_steps do |t|
      t.references :agent_run, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :kind, null: false
      t.string :tool_name
      t.jsonb :input
      t.jsonb :output
      t.integer :latency_ms
      t.integer :tokens

      t.timestamps
    end
    add_index :agent_steps, %i[agent_run_id position], unique: true
  end
end
