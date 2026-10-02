require "rails_helper"

RSpec.describe "Api::PersonalAccessTokens", type: :request do
  let(:company) { create(:company) }
  let(:person) { create(:person, company: company) }
  let(:base) { "/api/companies/#{company.id}/personal_access_tokens" }

  describe "POST" do
    it "issues a token for the signed-in person and returns the raw value exactly once" do
      sign_in(person)

      post base, params: { name: "Claude Desktop" }, as: :json

      expect(response).to have_http_status(:created)
      data = response.parsed_body["data"]
      expect(data).to include("name" => "Claude Desktop")
      expect(data["token"]).to start_with("keel_pat_")
      expect(PersonalAccessToken.authenticate(data["token"]).person).to eq(person)

      get base
      expect(response.parsed_body["data"].first).not_to have_key("token")
    end

    it "needs a name, and a signed-in person" do
      post base, params: { name: "x" }, as: :json
      expect(response).to have_http_status(:unauthorized)

      sign_in(person)
      post base, params: { name: "" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET" do
    it "lists only the signed-in person's active tokens" do
      sign_in(person)
      mine, = PersonalAccessToken.issue!(person, name: "Mine")
      PersonalAccessToken.issue!(person, name: "Old")[0].update!(revoked_at: Time.current)
      PersonalAccessToken.issue!(create(:person, company: company), name: "Theirs")

      get base

      expect(response.parsed_body["data"].map { _1["id"] }).to eq([ mine.id ])
    end
  end

  describe "DELETE" do
    it "revokes one of the person's own tokens, which then stops authenticating" do
      sign_in(person)
      token, raw = PersonalAccessToken.issue!(person, name: "Mine")

      delete "#{base}/#{token.id}"

      expect(response).to have_http_status(:ok)
      expect(PersonalAccessToken.authenticate(raw)).to be_nil
    end

    it "can't revoke someone else's token" do
      sign_in(person)
      theirs, raw = PersonalAccessToken.issue!(create(:person, company: company), name: "Theirs")

      delete "#{base}/#{theirs.id}"

      expect(response).to have_http_status(:not_found)
      expect(PersonalAccessToken.authenticate(raw)).to be_present
    end
  end
end
