require "rails_helper"

RSpec.describe InsightQuery, type: :model do
  it "is valid with a company, the person who asked, and a question" do
    expect(build(:insight_query)).to be_valid
  end

  it "requires a question" do
    insight_query = build(:insight_query, question: " ")

    expect(insight_query).not_to be_valid
    expect(insight_query.errors[:question]).to be_present
  end

  it "requires status to be one of pending, answered, needs_clarification or failed" do
    insight_query = build(:insight_query, status: "nonsense")

    expect(insight_query).not_to be_valid
    expect(insight_query.errors[:status]).to be_present
  end

  it "defaults to pending, with nothing interpreted yet" do
    insight_query = create(:insight_query)

    expect(insight_query).to have_attributes(status: "pending", query: nil, result: nil)
  end
end
