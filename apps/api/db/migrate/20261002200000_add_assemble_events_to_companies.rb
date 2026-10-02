class AddAssembleEventsToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :assemble_events, :jsonb, default: [], null: false
  end
end
