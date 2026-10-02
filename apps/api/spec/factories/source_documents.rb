FactoryBot.define do
  factory :source_document do
    company
    filename { "employee-handbook.pdf" }
    kind { "handbook" }
  end
end
