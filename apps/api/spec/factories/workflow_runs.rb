FactoryBot.define do
  factory :workflow_run do
    request
    workflow
    status { "in_progress" }
  end
end
