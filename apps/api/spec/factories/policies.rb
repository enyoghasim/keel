FactoryBot.define do
  factory :policy do
    company
    title { "Expense Policy" }
    category { "expense" }
  end
end
