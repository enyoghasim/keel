FactoryBot.define do
  factory :agent_run do
    company
    person { association :person, company: company }
    message { "Can I expense a €1,200 flight to RubyConf?" }
  end
end
