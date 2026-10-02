FactoryBot.define do
  factory :prompt_version do
    key { "policy_extractor" }
    sequence(:version)
    template { "Extract {{category}} rules from:\n{{excerpt}}" }
  end
end
