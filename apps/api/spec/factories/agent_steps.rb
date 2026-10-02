FactoryBot.define do
  factory :agent_step do
    agent_run
    sequence(:position)
    kind { "tool" }
    tool_name { "check_policy" }
    input { { "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } } }
    output { { "outcome" => "require_approval" } }
    latency_ms { 12 }
  end
end
