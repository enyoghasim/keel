class AddCrossReferenceForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :departments, :people, column: :head_id
    add_foreign_key :people, :people, column: :manager_id
  end
end
