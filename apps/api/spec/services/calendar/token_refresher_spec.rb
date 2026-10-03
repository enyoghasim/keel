require "rails_helper"

RSpec.describe Calendar::TokenRefresher do
  let(:company) { create(:company) }
  let(:integration) do
    create(:integration, company: company, kind: "google_calendar", status: "connected", credentials: {
      "access_token" => "old-token", "refresh_token" => "refresh-abc", "expires_at" => expires_at.iso8601
    })
  end

  context "when the stored access token still has time left" do
    let(:expires_at) { 10.minutes.from_now }

    it "returns it without calling Google" do
      allow(Faraday).to receive(:post)

      expect(described_class.call(integration)).to eq("old-token")
      expect(Faraday).not_to have_received(:post)
    end
  end

  context "when the stored access token is at or past expiry" do
    let(:expires_at) { 1.minute.from_now }
    let(:response) { instance_double(Faraday::Response, success?: true, status: 200, body: { access_token: "new-token", expires_in: 3600 }.to_json) }

    it "refreshes it with Google and persists the new token" do
      allow(Faraday).to receive(:post).and_return(response)

      expect(described_class.call(integration)).to eq("new-token")
      expect(Faraday).to have_received(:post).with("https://oauth2.googleapis.com/token")
      expect(integration.reload.credentials).to include("access_token" => "new-token", "refresh_token" => "refresh-abc")
    end

    it "sends the refresh token as a form-encoded body" do
      request = instance_double("Faraday::Request")
      allow(request).to receive(:headers).and_return({})
      allow(request).to receive(:body=)
      allow(Faraday).to receive(:post).and_yield(request).and_return(response)

      described_class.call(integration)

      expect(request).to have_received(:body=).with(a_string_including("refresh_token=refresh-abc", "grant_type=refresh_token"))
    end

    it "raises when Google rejects the refresh" do
      allow(response).to receive(:success?).and_return(false)
      allow(response).to receive(:status).and_return(400)
      allow(Faraday).to receive(:post).and_return(response)

      expect { described_class.call(integration) }.to raise_error(/400/)
    end
  end
end
