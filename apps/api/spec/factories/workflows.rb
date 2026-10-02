FactoryBot.define do
  factory :workflow do
    company
    sequence(:name) { |n| "Workflow #{n}" }
    trigger { { "request_kind" => "expense" } }
    steps { [] }
    status { "active" }

    trait :draft do
      status { "draft" }
    end
  end
end
