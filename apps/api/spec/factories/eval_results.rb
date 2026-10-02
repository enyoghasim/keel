FactoryBot.define do
  factory :eval_result do
    eval_run
    eval_case
    passed { true }
  end
end
