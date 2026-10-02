require "rails_helper"

RSpec.describe ChangeProposalChannel, type: :channel do
  it "streams a company's proposal updates" do
    company = create(:company)

    subscribe(company_id: company.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(company)
  end
end
