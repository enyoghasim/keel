FactoryBot.define do
  factory :workflow_edit do
    company
    person { association :person, company: company, roles: [ "hr_admin" ] }
    workflow { association :workflow, company: company }
    instruction { "Add a step where IT sets up accounts after the manager approves" }
  end
end
