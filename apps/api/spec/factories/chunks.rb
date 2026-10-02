FactoryBot.define do
  factory :chunk do
    source_document
    page { 1 }
    position { 0 }
    text { "Engineers attending conferences are automatically approved up to €1,000." }
  end
end
