class StepRun < ApplicationRecord
  belongs_to :workflow_run
  belongs_to :resolved_person, class_name: "Person", optional: true

  validates :step_key, presence: true
end
