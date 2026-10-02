class CreateInsightQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :insight_queries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.text :question, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :query
      t.text :clarification
      t.jsonb :result
      t.text :error_message
      t.string :model

      t.timestamps
    end
  end
end
