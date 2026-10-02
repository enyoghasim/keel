class AddAgentRunToChangeProposals < ActiveRecord::Migration[8.0]
  def change
    add_reference :change_proposals, :agent_run, foreign_key: true, null: true
  end
end
