class CreateWorkflowEdits < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_edits do |t|
      t.references :company, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.references :change_proposal, foreign_key: true
      t.text :instruction, null: false
      t.string :status, null: false, default: "pending"
      t.text :error_message
      t.string :model

      t.timestamps
    end
  end
end
