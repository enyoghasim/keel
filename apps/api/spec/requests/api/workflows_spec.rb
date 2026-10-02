require "rails_helper"

RSpec.describe "Api::Workflows", type: :request do
  describe "GET /api/companies/:company_id/workflows" do
    it "lists the company's workflows" do
      company = create(:company)
      workflow = create(:workflow, company: company)
      create(:workflow) # a different company's workflow, must not show up

      get "/api/companies/#{company.id}/workflows"

      ids = response.parsed_body["data"].map { _1["id"] }
      expect(ids).to eq([ workflow.id ])
    end
  end

  describe "GET /api/companies/:company_id/workflows/:id" do
    it "returns the workflow with its steps" do
      company = create(:company)
      workflow = create(:workflow, company: company, steps: [ { "key" => "approval", "type" => "approval" } ])

      get "/api/companies/#{company.id}/workflows/#{workflow.id}"

      body = response.parsed_body["data"]
      expect(body["id"]).to eq(workflow.id)
      expect(body["steps"]).to eq([ { "key" => "approval", "type" => "approval" } ])
    end
  end

  describe "POST /api/companies/:company_id/workflows/:id/test_run" do
    it "previews the steps a real request would take, with nothing persisted" do
      company = create(:company)
      manager = create(:person, company: company)
      finance_lead = create(:person, :finance_lead, company: company)
      requester = create(:person, company: company, manager: manager)
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "big_expense",
                     conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
                     actions: { "decision" => "require_approval", "approvers" => [ "role:finance_lead" ] })
      workflow = create(:workflow, company: company, trigger: { "request_kind" => "expense" },
                         steps: [ { "key" => "approval", "type" => "approval" } ])

      post "/api/companies/#{company.id}/workflows/#{workflow.id}/test_run",
        params: { requester_id: requester.id, payload: { amount_eur: 900 } }, as: :json

      body = response.parsed_body["data"]
      expect(body["outcome"]).to eq("require_approval")
      expect(body["steps"]).to eq([
        { "step_key" => "approval", "type" => "approval", "reference" => "person:#{finance_lead.id}",
          "resolved_person_id" => finance_lead.id, "matched" => true }
      ])
      expect(WorkflowRun.count).to eq(0)
      expect(StepRun.count).to eq(0)
    end

    it "previews a terminal, auto-approve decision with a single system step" do
      company = create(:company)
      requester = create(:person, company: company)
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "small_expense",
                     conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 },
                     actions: { "decision" => "auto_approve" })
      workflow = create(:workflow, company: company, trigger: { "request_kind" => "expense" })

      post "/api/companies/#{company.id}/workflows/#{workflow.id}/test_run",
        params: { requester_id: requester.id, payload: { amount_eur: 100 } }, as: :json

      body = response.parsed_body["data"]
      expect(body["outcome"]).to eq("auto_approve")
      expect(body["steps"]).to eq([
        { "step_key" => "system", "type" => "system", "reference" => nil, "resolved_person_id" => nil, "matched" => true }
      ])
    end

    it "returns an error envelope when requester_id is missing" do
      company = create(:company)
      workflow = create(:workflow, company: company)

      post "/api/companies/#{company.id}/workflows/#{workflow.id}/test_run", params: { payload: {} }, as: :json

      expect(response.parsed_body["success"]).to eq(false)
    end

    it "returns an error envelope when the requester isn't in this company" do
      company = create(:company)
      outsider = create(:person)
      workflow = create(:workflow, company: company)

      post "/api/companies/#{company.id}/workflows/#{workflow.id}/test_run",
        params: { requester_id: outsider.id, payload: {} }, as: :json

      expect(response.parsed_body["success"]).to eq(false)
    end
  end
end
