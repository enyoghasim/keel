require "rails_helper"

RSpec.describe "Api::Insights", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:person) { create(:person, company: company) }

  describe "POST /api/companies/:company_id/insights" do
    it "records the question as pending and hands it to InsightJob, without waiting on the model" do
      sign_in(person)

      expect {
        post "/api/companies/#{company.id}/insights", params: { question: "Leave days by department last quarter" }, as: :json
      }.to have_enqueued_job(InsightJob)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body["data"]
      expect(body).to include("question" => "Leave days by department last quarter", "status" => "pending", "person_id" => person.id)
      expect(InsightQuery.find(body["id"]).company).to eq(company)
    end

    it "rejects a blank question" do
      sign_in(person)

      post "/api/companies/#{company.id}/insights", params: { question: "  " }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(InsightQuery.count).to eq(0)
    end

    it "requires sign-in" do
      post "/api/companies/#{company.id}/insights", params: { question: "Anything" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses to ask about a company the signed-in person doesn't belong to" do
      sign_in(person)
      other = create(:company)

      post "/api/companies/#{other.id}/insights", params: { question: "Anything" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/companies/:company_id/insights" do
    it "lists the signed-in person's own recent questions, newest first" do
      sign_in(person)
      older = create(:insight_query, company: company, person: person, created_at: 2.days.ago)
      newer = create(:insight_query, company: company, person: person, created_at: 1.day.ago)
      create(:insight_query, company: company) # someone else's

      get "/api/companies/#{company.id}/insights"

      expect(response.parsed_body["data"].map { _1["id"] }).to eq([ newer.id, older.id ])
    end
  end

  describe "GET /api/companies/:company_id/insights/:id" do
    it "returns the question with how it was understood and the computed rows" do
      sign_in(person)
      insight_query = create(:insight_query, company: company, person: person, status: "answered",
        query: { "metric" => "request_count", "chart" => "table" },
        result: { "rows" => [ { "key" => nil, "label" => "Total", "value" => 3.0 } ], "unit" => "count", "summary" => "Overall: 3 requests." })

      get "/api/companies/#{company.id}/insights/#{insight_query.id}"

      expect(response.parsed_body["data"]).to include(
        "status" => "answered", "query" => { "metric" => "request_count", "chart" => "table" },
        "result" => include("summary" => "Overall: 3 requests.")
      )
    end

    it "doesn't find another company's question" do
      sign_in(person)
      other = create(:insight_query)

      get "/api/companies/#{company.id}/insights/#{other.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
