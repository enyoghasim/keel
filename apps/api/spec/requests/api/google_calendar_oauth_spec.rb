require "rails_helper"

RSpec.describe "Api::GoogleCalendarOauth", type: :request do
  let(:company) { create(:company) }
  let(:hr) { create(:person, :hr_admin, company: company) }
  let(:base) { "/api/companies/#{company.id}/integrations/google_calendar" }

  def state_for(a_company) = Rails.application.message_verifier(:google_calendar_oauth).generate(a_company.id, purpose: :google_calendar_oauth, expires_in: 10.minutes)

  describe "GET /authorize" do
    it "redirects to Google's consent screen with this company signed into the state" do
      sign_in(hr)

      get "#{base}/authorize"

      expect(response).to have_http_status(:found)
      uri = URI.parse(response.headers["Location"])
      expect("#{uri.scheme}://#{uri.host}#{uri.path}").to eq("https://accounts.google.com/o/oauth2/v2/auth")
      query = Rack::Utils.parse_query(uri.query)
      expect(query).to include("client_id" => "test-client-id", "access_type" => "offline", "scope" => a_string_including("calendar"))
      expect(Rails.application.message_verifier(:google_calendar_oauth).verify(query["state"], purpose: :google_calendar_oauth)).to eq(company.id)
    end

    it "is for hr_admins only" do
      sign_in(create(:person, company: company))

      get "#{base}/authorize"

      expect(response).to have_http_status(:forbidden)
    end

    it "requires sign-in" do
      get "#{base}/authorize"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /callback" do
    let(:token_response) { instance_double(Faraday::Response, success?: true, status: 200, body: { access_token: "new-access", refresh_token: "new-refresh", expires_in: 3600 }.to_json) }

    it "exchanges the code for tokens and connects the integration" do
      sign_in(hr)
      allow(Faraday).to receive(:post).and_return(token_response)

      get "#{base}/callback", params: { code: "auth-code", state: state_for(company) }

      expect(response).to redirect_to("/settings")
      integration = company.integrations.find_by!(kind: "google_calendar")
      expect(integration.status).to eq("connected")
      expect(integration.credentials).to include("access_token" => "new-access", "refresh_token" => "new-refresh")
    end

    it "keeps the existing refresh token when Google doesn't send a new one (reconnect)" do
      sign_in(hr)
      create(:integration, company: company, kind: "google_calendar", status: "connected",
        credentials: { "access_token" => "old", "refresh_token" => "keep-me", "expires_at" => 1.hour.ago.iso8601 })
      no_refresh_response = instance_double(Faraday::Response, success?: true, status: 200, body: { access_token: "new-access", expires_in: 3600 }.to_json)
      allow(Faraday).to receive(:post).and_return(no_refresh_response)

      get "#{base}/callback", params: { code: "auth-code", state: state_for(company) }

      expect(company.integrations.find_by!(kind: "google_calendar").credentials).to include("refresh_token" => "keep-me")
    end

    it "redirects with an error and makes no change when the state doesn't verify" do
      sign_in(hr)
      allow(Faraday).to receive(:post)

      get "#{base}/callback", params: { code: "auth-code", state: "not-a-real-token" }

      expect(URI.parse(response.headers["Location"]).path).to eq("/settings")
      expect(response.headers["Location"]).to include("calendar_error")
      expect(company.integrations.where(kind: "google_calendar")).to be_none
      expect(Faraday).not_to have_received(:post)
    end

    it "redirects with an error and makes no change when Google declines the code" do
      sign_in(hr)
      allow(Faraday).to receive(:post).and_return(instance_double(Faraday::Response, success?: false, status: 400, body: "invalid_grant"))

      get "#{base}/callback", params: { code: "auth-code", state: state_for(company) }

      expect(response.headers["Location"]).to include("calendar_error")
      expect(company.integrations.where(kind: "google_calendar")).to be_none
    end

    it "redirects with an error when Google reports the user cancelled" do
      sign_in(hr)

      get "#{base}/callback", params: { error: "access_denied" }

      expect(response.headers["Location"]).to include("calendar_error")
    end
  end
end
