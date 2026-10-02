class CreateImportIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :import_issues do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :row_number, null: false
      t.string :field, null: false
      t.string :raw_value
      t.string :message, null: false
      t.boolean :resolved, null: false, default: false

      t.timestamps
    end
  end
end
