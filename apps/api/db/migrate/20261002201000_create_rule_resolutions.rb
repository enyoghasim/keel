class CreateRuleResolutions < ActiveRecord::Migration[8.0]
  def change
    create_table :rule_resolutions do |t|
      t.references :company, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :rule, null: false, foreign_key: true
      t.references :new_rule, foreign_key: { to_table: :rules }
      t.integer :ambiguity_index, null: false
      t.string :answer, null: false
      t.string :status, null: false, default: "pending"
      t.text :error_message
      t.string :model
      t.timestamps
    end
  end
end
