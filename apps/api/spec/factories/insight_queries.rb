FactoryBot.define do
  factory :insight_query do
    company
    person { association :person, company: company }
    question { "Leave days by department last quarter" }
  end
end
