FactoryBot.define do
  factory :integration do
    company
    kind { "slack" }
    status { "connected" }
    credentials { { "webhook_url" => "https://hooks.slack.com/services/test" } }
  end
end
