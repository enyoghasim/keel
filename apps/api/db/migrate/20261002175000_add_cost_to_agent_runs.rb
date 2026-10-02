class AddCostToAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_runs, :cost_usd, :decimal, precision: 10, scale: 6
  end
end
