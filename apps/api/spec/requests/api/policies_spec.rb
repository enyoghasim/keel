require "rails_helper"

RSpec.describe "Api::Policies", type: :request do
  describe "GET /api/companies/:company_id/policies" do
    it "lists the company's policies" do
      company = create(:company)
      policy = create(:policy, company: company)
      create(:policy) # a different company's policy, must not show up

      get "/api/companies/#{company.id}/policies"

      ids = response.parsed_body["data"].map { _1["id"] }
      expect(ids).to eq([ policy.id ])
    end
  end

  describe "GET /api/companies/:company_id/policies/:id" do
    it "returns the policy with its rules" do
      company = create(:company)
      policy = create(:policy, company: company)
      rule = create(:rule, policy: policy)

      get "/api/companies/#{company.id}/policies/#{policy.id}"

      body = response.parsed_body["data"]
      expect(body["id"]).to eq(policy.id)
      expect(body["rules"].map { _1["id"] }).to eq([ rule.id ])
    end
  end

  describe "POST /api/companies/:company_id/policies/:id/test" do
    it "evaluates the scenario live against the policy's rules" do
      company = create(:company)
      requester = create(:person, company: company)
      policy = create(:policy, company: company, category: "expense")
      create(:rule, policy: policy, conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 },
                     actions: { "decision" => "auto_approve" }, key: "small_expense")

      post "/api/companies/#{company.id}/policies/#{policy.id}/test",
        params: { requester_id: requester.id, payload: { amount_eur: 900 } }, as: :json

      body = response.parsed_body["data"]
      expect(body["outcome"]).to eq("auto_approve")
      expect(body["matched_rule_keys"]).to eq([ "small_expense" ])
    end

    it "falls back to requiring the manager's approval when no rule matches" do
      company = create(:company)
      manager = create(:person, company: company)
      requester = create(:person, company: company, manager: manager)
      policy = create(:policy, company: company, category: "expense")
      create(:rule, policy: policy, conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 1000 },
                     actions: { "decision" => "auto_approve" })

      post "/api/companies/#{company.id}/policies/#{policy.id}/test",
        params: { requester_id: requester.id, payload: { amount_eur: 5000 } }, as: :json

      body = response.parsed_body["data"]
      expect(body["outcome"]).to eq("require_approval")
      expect(body["approvers"]).to eq([ manager.id ])
    end

    it "returns an error envelope when requester_id is missing" do
      company = create(:company)
      policy = create(:policy, company: company)

      post "/api/companies/#{company.id}/policies/#{policy.id}/test", params: { payload: { amount_eur: 100 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "returns an error envelope when the requester isn't in this company" do
      company = create(:company)
      policy = create(:policy, company: company)
      outsider = create(:person)

      post "/api/companies/#{company.id}/policies/#{policy.id}/test",
        params: { requester_id: outsider.id, payload: { amount_eur: 100 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
    end
  end
end
