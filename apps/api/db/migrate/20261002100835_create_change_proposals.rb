class CreateChangeProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :change_proposals do |t|
      t.references :company, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :title, null: false
      t.jsonb :diff, null: false, default: []
      t.jsonb :impact, null: false, default: {}
      t.string :proposed_by, null: false, default: "user"
      t.string :status, null: false, default: "pending"
      t.references :decided_by, null: true, foreign_key: { to_table: :people }
      t.datetime :decided_at

      t.timestamps
    end
  end
end
