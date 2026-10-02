FactoryBot.define do
  factory :rule do
    policy
    source_chunk { association :chunk }
    key { "expense_conference_engineering" }
    conditions { { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 } }
    actions { { "decision" => "auto_approve" } }
    priority { 10 }
    source_quote { "Engineers attending conferences are automatically approved up to €1,000." }
  end
end
