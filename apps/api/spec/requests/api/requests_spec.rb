require "rails_helper"

RSpec.describe "Api::Requests", type: :request do
  describe "POST /api/companies/:company_id/requests" do
    it "auto-approves when the matching active rule says so, with no workflow involved" do
      company = create(:company)
      requester = create(:person, company: company)
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "small_expense",
                     conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
                     actions: { "decision" => "auto_approve" })
      sign_in(requester)

      post "/api/companies/#{company.id}/requests",
        params: { requester_id: requester.id, kind: "expense", payload: { amount_eur: 100 } }, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body["data"]
      expect(body["decision"]).to eq("auto_approve")
      expect(body["status"]).to eq("approved")
      expect(body["workflow_run"]["step_runs"].sole).to include("step_key" => "system", "status" => "done")
    end

    it "starts the matching workflow and resolves the first step when approval is required" do
      company = create(:company)
      manager = create(:person, company: company)
      requester = create(:person, company: company, manager: manager)
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "big_expense",
                     conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
                     actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
      create(:workflow, company: company, status: "active", trigger: { "request_kind" => "expense" },
                         steps: [ { "key" => "manager", "type" => "approval", "assignee" => "manager_of(requester)" } ])
      sign_in(requester)

      post "/api/companies/#{company.id}/requests",
        params: { requester_id: requester.id, kind: "expense", payload: { amount_eur: 900 } }, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body["data"]
      expect(body["decision"]).to eq("require_approval")
      step_run = body["workflow_run"]["step_runs"].sole
      expect(step_run).to include("step_key" => "manager", "status" => "pending", "resolved_person_id" => manager.id)
    end

    it "returns an error envelope when no active workflow matches the decided request kind" do
      company = create(:company)
      requester = create(:person, company: company, manager: create(:person, company: company))
      sign_in(requester)

      post "/api/companies/#{company.id}/requests",
        params: { requester_id: requester.id, kind: "expense", payload: { amount_eur: 900 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
      expect(Request.count).to eq(0)
    end

    it "returns an error envelope when the requester isn't in this company" do
      company = create(:company)
      outsider = create(:person)
      sign_in(create(:person, :hr_admin, company: company))

      post "/api/companies/#{company.id}/requests",
        params: { requester_id: outsider.id, kind: "expense", payload: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "returns a 401 envelope when no one is signed in" do
      company = create(:company)
      requester = create(:person, company: company)

      post "/api/companies/#{company.id}/requests",
        params: { requester_id: requester.id, kind: "expense", payload: {} }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Request.count).to eq(0)
    end

    it "returns a 403 envelope when filing on behalf of someone else without hr_admin" do
      company = create(:company)
      requester = create(:person, company: company)
      someone_else = create(:person, company: company)
      sign_in(someone_else)

      post "/api/companies/#{company.id}/requests",
        params: { requester_id: requester.id, kind: "expense", payload: {} }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Request.count).to eq(0)
    end

    it "lets an hr_admin file a request on behalf of someone else" do
      company = create(:company)
      requester = create(:person, company: company)
      admin = create(:person, :hr_admin, company: company)
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "small_expense",
                     conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
                     actions: { "decision" => "auto_approve" })
      sign_in(admin)

      post "/api/companies/#{company.id}/requests",
        params: { requester_id: requester.id, kind: "expense", payload: { amount_eur: 100 } }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]["requester_id"]).to eq(requester.id)
    end
  end

  describe "GET /api/companies/:company_id/requests" do
    it "lists the company's requests, optionally filtered by requester" do
      company = create(:company)
      requester = create(:person, company: company)
      other = create(:person, company: company)
      mine = create(:request, company: company, requester: requester)
      create(:request, company: company, requester: other)

      get "/api/companies/#{company.id}/requests", params: { requester_id: requester.id }

      ids = response.parsed_body["data"].map { _1["id"] }
      expect(ids).to eq([ mine.id ])
    end

    it "loads workflow runs and step runs in a constant number of queries" do
      company = create(:company)
      requester = create(:person, company: company)
      queries = lambda do
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          get "/api/companies/#{company.id}/requests"
        end
        count
      end
      2.times { create(:workflow_run, request: create(:request, company: company, requester: requester)) }
      before_count = queries.call

      5.times { create(:step_run, workflow_run: create(:workflow_run, request: create(:request, company: company, requester: requester))) }

      expect(queries.call).to eq(before_count)
    end
  end

  describe "GET /api/companies/:company_id/requests/:id" do
    it "returns the request with its workflow run and step runs" do
      company = create(:company)
      request_record = create(:request, company: company)

      get "/api/companies/#{company.id}/requests/#{request_record.id}"

      expect(response.parsed_body["data"]["id"]).to eq(request_record.id)
    end
  end
end
