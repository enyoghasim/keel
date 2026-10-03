class AddHumanAuthoredToWorkflowEdits < ActiveRecord::Migration[8.0]
  def change
    change_column_null :workflow_edits, :instruction, true
    add_column :workflow_edits, :source, :string, null: false, default: "instruction"
    add_column :workflow_edits, :after_steps, :jsonb
  end
end
