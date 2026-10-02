class CreateWorkflows < ActiveRecord::Migration[8.1]
  def change
    create_table :workflows do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :trigger, null: false, default: {}
      t.jsonb :steps, null: false, default: []
      t.integer :version, null: false, default: 1
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
  end
end
