require "rails_helper"

RSpec.describe McpCallChannel, type: :channel do
  it "streams one person's MCP calls" do
    person = create(:person)

    subscribe(person_id: person.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(person)
  end
end
