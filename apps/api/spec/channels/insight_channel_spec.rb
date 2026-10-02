require "rails_helper"

RSpec.describe InsightChannel, type: :channel do
  it "streams one insight query's updates and sends its current state straight away" do
    insight_query = create(:insight_query, status: "answered", result: { "rows" => [], "unit" => "count", "summary" => "x" })

    subscribe(insight_query_id: insight_query.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(insight_query)
    # The job may finish between the POST that created the query and this
    # subscription — sending the current state on subscribe closes that gap
    # without the page having to poll.
    expect(transmissions.last).to include("id" => insight_query.id, "status" => "answered")
  end
end
