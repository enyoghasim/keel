class CreateChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :chunks do |t|
      t.references :source_document, null: false, foreign_key: true
      t.integer :page, null: false
      t.integer :position, null: false
      t.text :text, null: false
      t.vector :embedding, limit: 1536

      t.timestamps
    end
  end
end
