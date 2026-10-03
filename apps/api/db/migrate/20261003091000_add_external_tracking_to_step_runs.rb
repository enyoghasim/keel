class AddExternalTrackingToStepRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :step_runs, :external_status, :string
    add_column :step_runs, :external_ref, :string
    add_column :step_runs, :external_error, :text
  end
end
