require "rails_helper"

RSpec.describe "Api::Integrations", type: :request do
  let(:company) { create(:company) }
  let(:hr) { create(:person, :hr_admin, company: company) }
  let(:base) { "/api/companies/#{company.id}/integrations" }

  describe "POST" do
    it "connects Slack from a webhook URL, never returning the credentials back" do
      sign_in(hr)

      post base, params: { kind: "slack", webhook_url: "https://hooks.slack.com/services/abc" }, as: :json

      expect(response).to have_http_status(:created)
      data = response.parsed_body["data"]
      expect(data).to include("kind" => "slack", "status" => "connected")
      expect(data).not_to have_key("credentials")
      expect(Integration.sole.credentials).to eq({ "webhook_url" => "https://hooks.slack.com/services/abc" })
    end

    it "rejects a URL that isn't a real Slack webhook" do
      sign_in(hr)

      post base, params: { kind: "slack", webhook_url: "https://evil.example.com/steal" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Integration.count).to eq(0)
    end

    it "replaces an existing connection of the same kind rather than erroring on the uniqueness constraint" do
      sign_in(hr)
      create(:integration, company: company, kind: "slack", credentials: { "webhook_url" => "https://hooks.slack.com/services/old" })

      post base, params: { kind: "slack", webhook_url: "https://hooks.slack.com/services/new" }, as: :json

      expect(response).to have_http_status(:created)
      expect(Integration.sole.credentials).to eq({ "webhook_url" => "https://hooks.slack.com/services/new" })
    end

    it "is for hr_admins only" do
      sign_in(create(:person, company: company))

      post base, params: { kind: "slack", webhook_url: "https://hooks.slack.com/services/abc" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "requires sign-in" do
      post base, params: { kind: "slack", webhook_url: "https://hooks.slack.com/services/abc" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET" do
    it "lists the company's integrations without their credentials" do
      sign_in(hr)
      create(:integration, company: company, kind: "slack")

      get base

      data = response.parsed_body["data"]
      expect(data.sole).to include("kind" => "slack", "status" => "connected")
      expect(data.sole).not_to have_key("credentials")
    end
  end

  describe "DELETE" do
    it "disconnects an integration" do
      sign_in(hr)
      integration = create(:integration, company: company, kind: "slack")

      delete "#{base}/#{integration.id}"

      expect(response).to have_http_status(:ok)
      expect(Integration.exists?(integration.id)).to be(false)
    end
  end
end
