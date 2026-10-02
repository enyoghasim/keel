require "rails_helper"

RSpec.describe "Api::Sessions", type: :request do
  describe "POST /api/companies/:company_id/session" do
    it "signs a person in with the demo password and sets the session cookie" do
      company = create(:company)
      ada = create(:person, company: company, email: "ada@nubo.example")

      post "/api/companies/#{company.id}/session",
        params: { email: "ada@nubo.example", password: Person::DEMO_PASSWORD }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]["id"]).to eq(ada.id)
      expect(response.parsed_body["data"]).not_to have_key("password_digest")
      expect(response.cookies["keel_session"]).to be_present
    end

    it "rejects a wrong password" do
      company = create(:company)
      create(:person, company: company, email: "ada@nubo.example")

      post "/api/companies/#{company.id}/session",
        params: { email: "ada@nubo.example", password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "rejects an unknown email" do
      company = create(:company)

      post "/api/companies/#{company.id}/session",
        params: { email: "nobody@nubo.example", password: Person::DEMO_PASSWORD }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "scopes the email lookup to the given company" do
      other_company_person = create(:person, email: "ada@nubo.example")
      company = create(:company)

      post "/api/companies/#{company.id}/session",
        params: { email: "ada@nubo.example", password: Person::DEMO_PASSWORD }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(other_company_person).to be_persisted
    end
  end

  describe "GET /api/companies/:company_id/session" do
    it "returns the signed-in person" do
      company = create(:company)
      ada = create(:person, company: company, email: "ada@nubo.example")
      post "/api/companies/#{company.id}/session",
        params: { email: "ada@nubo.example", password: Person::DEMO_PASSWORD }, as: :json

      get "/api/companies/#{company.id}/session"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]["id"]).to eq(ada.id)
    end

    it "returns 401 when no one is signed in" do
      company = create(:company)

      get "/api/companies/#{company.id}/session"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/companies/:company_id/session" do
    it "signs the person out" do
      company = create(:company)
      create(:person, company: company, email: "ada@nubo.example")
      post "/api/companies/#{company.id}/session",
        params: { email: "ada@nubo.example", password: Person::DEMO_PASSWORD }, as: :json

      delete "/api/companies/#{company.id}/session"
      get "/api/companies/#{company.id}/session"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # Which command-bar conversation is open lives with the session on the
  # server, so a refresh (or another tab) brings the same thread back.
  describe "the open agent conversation" do
    let(:company) { create(:company) }
    let(:person) { create(:person, company: company) }

    it "starts with none, remembers one of the person's own, and can be cleared" do
      sign_in(person)
      run = create(:agent_run, company: company, person: person)
      expect(get("/api/companies/#{company.id}/session") && response.parsed_body["data"]["conversation_id"]).to be_nil

      patch "/api/companies/#{company.id}/session", params: { conversation_id: run.conversation_id }, as: :json
      expect(response).to have_http_status(:ok)

      get "/api/companies/#{company.id}/session"
      expect(response.parsed_body["data"]["conversation_id"]).to eq(run.conversation_id)

      patch "/api/companies/#{company.id}/session", params: { conversation_id: nil }, as: :json
      get "/api/companies/#{company.id}/session"
      expect(response.parsed_body["data"]["conversation_id"]).to be_nil
    end

    it "refuses a conversation that isn't the person's own" do
      sign_in(person)
      someone_elses = create(:agent_run, company: company)

      patch "/api/companies/#{company.id}/session", params: { conversation_id: someone_elses.conversation_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "needs a sign-in" do
      patch "/api/companies/#{company.id}/session", params: { conversation_id: nil }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
