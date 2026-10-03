require "rails_helper"

RSpec.describe Slack::Notifier do
  let(:company) { create(:company) }
  let(:response) { instance_double(Faraday::Response, success?: true, status: 200) }

  before do
    create(:integration, company: company, kind: "slack", status: "connected",
      credentials: { "webhook_url" => "https://hooks.slack.com/services/abc" })
    allow(Faraday).to receive(:post).and_return(response)
  end

  it "posts the message as JSON to the connected webhook URL" do
    described_class.call(company: company, text: "A leave request needs your approval.")

    expect(Faraday).to have_received(:post).with("https://hooks.slack.com/services/abc")
  end

  it "sends the text as a JSON body with the content type Slack expects" do
    request = instance_double("Faraday::Request")
    allow(request).to receive(:headers).and_return({})
    allow(request).to receive(:body=)
    allow(Faraday).to receive(:post).with("https://hooks.slack.com/services/abc").and_yield(request).and_return(response)

    described_class.call(company: company, text: "Hello")

    expect(request).to have_received(:body=).with({ text: "Hello" }.to_json)
  end

  it "raises when Slack doesn't return success" do
    allow(response).to receive(:success?).and_return(false)
    allow(response).to receive(:status).and_return(500)

    expect { described_class.call(company: company, text: "Hello") }.to raise_error(/500/)
  end

  it "raises when the company has no connected Slack integration" do
    other_company = create(:company)

    expect { described_class.call(company: other_company, text: "Hello") }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
