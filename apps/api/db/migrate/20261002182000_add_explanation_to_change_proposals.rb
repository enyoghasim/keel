class AddExplanationToChangeProposals < ActiveRecord::Migration[8.1]
  def change
    add_column :change_proposals, :explanation, :text
  end
end
