class WorkflowRun < ApplicationRecord
  belongs_to :request
  belongs_to :workflow, optional: true
  has_many :step_runs, dependent: :destroy
end
