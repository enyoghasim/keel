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

    it "starts a new conversation by default, and continues one of the person's own when asked" do
      sign_in(person)
      earlier = create(:agent_run, company: company, person: person)

      post "/api/companies/#{company.id}/agent_runs", params: { message: "Hi" }, as: :json
      expect(response.parsed_body["data"]["conversation_id"]).to be_present
      expect(response.parsed_body["data"]["conversation_id"]).not_to eq(earlier.conversation_id)

      post "/api/companies/#{company.id}/agent_runs", params: { message: "And €2,000?", conversation_id: earlier.conversation_id }, as: :json
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["data"]["conversation_id"]).to eq(earlier.conversation_id)
    end

    it "won't continue a conversation that isn't the person's, since replaying it would leak their messages" do
      sign_in(person)
      someone_elses = create(:agent_run, company: company)

      expect {
        post "/api/companies/#{company.id}/agent_runs", params: { message: "Hi", conversation_id: someone_elses.conversation_id }, as: :json
      }.not_to have_enqueued_job(AgentJob)

      expect(response).to have_http_status(:not_found)
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

  describe "GET /api/companies/:company_id/agent_runs" do
    it "lists the signed-in person's recent runs, newest first, capped, without anyone else's" do
      sign_in(person)
      create(:agent_run, company: company, person: person, message: "First", created_at: 2.hours.ago)
      create(:agent_run, company: company, person: person, message: "Second", created_at: 1.hour.ago)
      create(:agent_run, company: company)
      stub_const("Api::AgentRunsController::RECENT_LIMIT", 2)
      create(:agent_run, company: company, person: person, message: "Third", created_at: 1.minute.ago)

      get "/api/companies/#{company.id}/agent_runs"

      expect(response.parsed_body["data"].map { _1["message"] }).to eq(%w[Third Second])
      expect(response.parsed_body["data"].first).to include("status" => "pending", "steps" => [])
    end

    it "can narrow to one conversation, to reopen its thread" do
      sign_in(person)
      first = create(:agent_run, company: company, person: person, message: "Can I expense €1,200?", created_at: 2.hours.ago)
      create(:agent_run, company: company, person: person, message: "And €2,000?", conversation_id: first.conversation_id, created_at: 1.hour.ago)
      create(:agent_run, company: company, person: person, message: "Unrelated")

      get "/api/companies/#{company.id}/agent_runs", params: { conversation_id: first.conversation_id }

      expect(response.parsed_body["data"].map { _1["message"] }).to eq([ "And €2,000?", "Can I expense €1,200?" ])
    end

    it "requires sign-in, and membership of the company" do
      get "/api/companies/#{company.id}/agent_runs"
      expect(response).to have_http_status(:unauthorized)

      sign_in(person)
      get "/api/companies/#{create(:company).id}/agent_runs"
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
