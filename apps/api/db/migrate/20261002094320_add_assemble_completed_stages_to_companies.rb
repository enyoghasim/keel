class AddAssembleCompletedStagesToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :assemble_completed_stages, :string, array: true, null: false, default: []
  end
end
