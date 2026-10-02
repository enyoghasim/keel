class CreateSourceDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :source_documents do |t|
      t.references :company, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :kind, null: false
      t.integer :page_count

      t.timestamps
    end
  end
end
