class CreateIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :integrations do |t|
      t.references :company, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "disconnected"
      t.text :credentials
      t.text :error_message
      t.timestamps
    end
    add_index :integrations, [ :company_id, :kind ], unique: true
  end
end
