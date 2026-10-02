FactoryBot.define do
  factory :person do
    company
    department { association :department, company: company }
    sequence(:name) { |n| "Person #{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
    title { "Specialist" }
    location { "Lagos" }
    start_date { 1.year.ago.to_date }
    roles { [] }

    trait :without_manager do
      manager { nil }
    end

    trait :finance_lead do
      roles { [ "finance_lead" ] }
    end

    trait :it_admin do
      roles { [ "it_admin" ] }
    end
  end
end
