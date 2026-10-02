FactoryBot.define do
  factory :mcp_call do
    company
    person { association :person, company: company }
    tool_name { "check_policy" }
    input { { "request_kind" => "leave", "payload" => { "days" => 5 } } }
    output { { "decision" => "require_approval" } }
    is_error { false }
    latency_ms { 12 }
  end
end
