require "rails_helper"

RSpec.describe AssembleChannel, type: :channel do
  it "streams that company's own assemble events" do
    company = create(:company)

    subscribe(company_id: company.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(company)
  end
end
