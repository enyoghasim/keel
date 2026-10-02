class CreateMcpCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_calls do |t|
      t.references :company, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :personal_access_token, foreign_key: true
      t.string :tool_name, null: false
      t.jsonb :input, null: false, default: {}
      t.jsonb :output
      t.boolean :is_error, null: false, default: false
      t.integer :latency_ms

      t.timestamps
    end
  end
end
