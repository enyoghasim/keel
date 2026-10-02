FactoryBot.define do
  factory :request do
    company
    requester { association :person, company: company }
    kind { "expense" }
    payload { { "amount_eur" => 100 } }
  end
end
