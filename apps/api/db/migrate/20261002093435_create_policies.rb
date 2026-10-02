class CreatePolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :policies do |t|
      t.references :company, null: false, foreign_key: true
      t.string :title, null: false
      t.string :category, null: false
      t.string :status, null: false, default: "draft"
      t.integer :version, null: false, default: 1

      t.timestamps
    end
  end
end
