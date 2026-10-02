FactoryBot.define do
  factory :department do
    company
    sequence(:name) { |n| "Department #{n}" }
  end
end
