require "rails_helper"

RSpec.describe "Api::EvalRuns", type: :request do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:person, :hr_admin, company: company) }

  describe "POST /api/companies/:company_id/eval_runs" do
    it "starts a pending run of the suite and hands it to EvalRunJob, without waiting on the model" do
      sign_in(hr_admin)

      expect {
        post "/api/companies/#{company.id}/eval_runs", params: { suite: "insights" }, as: :json
      }.to have_enqueued_job(EvalRunJob)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["data"]).to include("suite" => "insights", "status" => "pending", "person_id" => hr_admin.id)
    end

    it "refuses a suite that has no runner yet" do
      sign_in(hr_admin)

      post "/api/companies/#{company.id}/eval_runs", params: { suite: "agent" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq("The agent suite can't be run yet. Runnable suites: insights.")
      expect(EvalRun.count).to eq(0)
    end

    it "only lets an hr_admin start a run, since every run spends model calls" do
      sign_in(create(:person, company: company))

      post "/api/companies/#{company.id}/eval_runs", params: { suite: "insights" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "requires sign-in" do
      post "/api/companies/#{company.id}/eval_runs", params: { suite: "insights" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/companies/:company_id/eval_runs" do
    it "lists the company's runs newest first, optionally for one suite, with how many active cases each suite has" do
      sign_in(hr_admin)
      older = create(:eval_run, company: company, created_at: 2.days.ago, status: "completed", accuracy: 0.8)
      newer = create(:eval_run, company: company, created_at: 1.day.ago)
      create(:eval_run) # another company's
      create_list(:eval_case, 2, suite: "insights")
      create(:eval_case, suite: "insights", status: "candidate")

      get "/api/companies/#{company.id}/eval_runs", params: { suite: "insights" }

      body = response.parsed_body
      expect(body["data"].map { _1["id"] }).to eq([ newer.id, older.id ])
      expect(body["data"].last["accuracy"]).to eq(0.8)
      expect(body["meta"]).to eq({ "active_cases" => { "insights" => 2 }, "runnable_suites" => [ "insights" ] })
    end
  end

  describe "GET /api/companies/:company_id/eval_runs/:id" do
    it "returns the run with every case's result, expected output and diff" do
      sign_in(hr_admin)
      eval_run = create(:eval_run, company: company, status: "completed")
      eval_case = create(:eval_case, key: "fiscal", expected: { "clarification" => true })
      create(:eval_result, eval_run: eval_run, eval_case: eval_case, passed: false,
        actual: { "query" => { "metric" => "leave_days", "chart" => "bar" } },
        diff: [ { "field" => "clarification", "expected" => true, "actual" => { "metric" => "leave_days", "chart" => "bar" } } ])

      get "/api/companies/#{company.id}/eval_runs/#{eval_run.id}"

      result = response.parsed_body.dig("data", "results", 0)
      expect(result).to include("case_key" => "fiscal", "passed" => false, "expected" => { "clarification" => true })
      expect(result["diff"].first["field"]).to eq("clarification")
    end

    it "doesn't find another company's run" do
      sign_in(hr_admin)

      get "/api/companies/#{company.id}/eval_runs/#{create(:eval_run).id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
