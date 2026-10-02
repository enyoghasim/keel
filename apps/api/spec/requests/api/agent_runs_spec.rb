require "rails_helper"

RSpec.describe "Api::AgentRuns", type: :request do
  let(:company) { create(:company) }
  let(:person) { create(:person, company: company) }

  describe "POST /api/companies/:company_id/agent_runs" do
    it "records the message as a pending run for the signed-in person and hands it to AgentJob" do
      sign_in(person)

      expect {
        post "/api/companies/#{company.id}/agent_runs", params: { message: "Request leave for 22–29 December" }, as: :json
      }.to have_enqueued_job(AgentJob)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["data"]).to include("message" => "Request leave for 22–29 December", "status" => "pending", "person_id" => person.id, "steps" => [])
    end

    it "rejects a blank message" do
      sign_in(person)

      post "/api/companies/#{company.id}/agent_runs", params: { message: " " }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires sign-in, and membership of the company" do
      post "/api/companies/#{company.id}/agent_runs", params: { message: "Hi" }, as: :json
      expect(response).to have_http_status(:unauthorized)

      sign_in(person)
      post "/api/companies/#{create(:company).id}/agent_runs", params: { message: "Hi" }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/companies/:company_id/agent_runs/:id" do
    it "returns the run with its full trace" do
      sign_in(person)
      agent_run = create(:agent_run, company: company, person: person, status: "completed", final_text: "Done.")
      create(:agent_step, agent_run: agent_run, position: 1, tool_name: "check_policy")

      get "/api/companies/#{company.id}/agent_runs/#{agent_run.id}"

      body = response.parsed_body["data"]
      expect(body).to include("final_text" => "Done.")
      expect(body["steps"].sole).to include("tool_name" => "check_policy")
    end

    it "doesn't show someone else's run, since a trace can contain their requests" do
      sign_in(person)
      other = create(:agent_run, company: company)

      get "/api/companies/#{company.id}/agent_runs/#{other.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
