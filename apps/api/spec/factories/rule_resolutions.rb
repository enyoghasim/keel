FactoryBot.define do
  factory :rule_resolution do
    company
    person { association :person, company: company, roles: [ "hr_admin" ] }
    rule { association :rule, policy: association(:policy, company: company), ambiguities: [ { "phrase" => "p", "question" => "Q?", "options" => [ "A", "B" ] } ] }
    ambiguity_index { 0 }
    answer { "A" }
  end
end
