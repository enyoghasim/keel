FactoryBot.define do
  factory :import_issue do
    company
    row_number { 2 }
    field { "manager" }
    raw_value { "Tunde Bakre" }
    message { "could not uniquely match manager 'Tunde Bakre'" }
  end
end
