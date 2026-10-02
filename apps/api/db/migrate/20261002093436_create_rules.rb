class CreateRules < ActiveRecord::Migration[8.1]
  def change
    create_table :rules do |t|
      t.references :policy, null: false, foreign_key: true
      t.references :source_chunk, null: false, foreign_key: { to_table: :chunks }
      t.string :key, null: false
      t.jsonb :conditions, null: false, default: {}
      t.jsonb :actions, null: false, default: {}
      t.integer :priority, null: false, default: 0
      t.text :source_quote, null: false
      t.jsonb :ambiguities, null: false, default: []
      t.string :status, null: false, default: "extracted"

      t.timestamps
    end
  end
end
