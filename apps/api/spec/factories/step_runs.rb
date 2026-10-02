FactoryBot.define do
  factory :step_run do
    workflow_run
    step_key { "manager" }
    reference { "manager_of(requester)" }
    status { "pending" }
  end
end
