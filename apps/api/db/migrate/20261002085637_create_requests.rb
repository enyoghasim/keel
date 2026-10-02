class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :requests do |t|
      t.references :company, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :people }
      t.string :kind, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :decision
      t.string :matched_rule_ids, array: true, null: false, default: []
      t.integer :policy_version
      t.string :status, null: false, default: "pending"

      t.timestamps
    end
  end
end
