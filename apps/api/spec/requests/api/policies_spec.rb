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

RSpec.describe "Api::Policies drafts", type: :request do
  let(:company) { create(:company) }
  let(:hr) { create(:person, :hr_admin, company: company) }
  let(:policy) { create(:policy, company: company, status: "draft", version: 1) }
  let(:base) { "/api/companies/#{company.id}/policies/#{policy.id}" }
  let(:ambiguity) { { "phrase" => "p", "question" => "Q?", "options" => [ "A", "B" ] } }

  def conflicting_rules
    create(:rule, policy: policy, key: "expense_over_500", status: "resolved", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 }, actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
    create(:rule, policy: policy, key: "travel_under_800", status: "resolved", priority: 1, actions: { "decision" => "auto_approve" },
      conditions: { "all" => [ { "field" => "payload.category", "op" => "eq", "value" => "travel" }, { "field" => "payload.amount_eur", "op" => "lt", "value" => 800 } ] })
  end

  describe "a superseded rule version" do
    it "is not shown, and does not take part in the tester" do
      old = create(:rule, policy: policy, key: "small", status: "superseded", actions: { "decision" => "reject", "reason" => "old" })
      current = create(:rule, policy: policy, key: "small", status: "resolved", actions: { "decision" => "auto_approve" })
      requester = create(:person, company: company)

      get base
      expect(response.parsed_body["data"]["rules"].map { _1["id"] }).to eq([ current.id ])

      post "#{base}/test", params: { requester_id: requester.id, payload: { amount_eur: 10 } }, as: :json
      expect(response.parsed_body["data"]["outcome"]).to eq("auto_approve")
      expect(old.reload.status).to eq("superseded")
    end
  end

  describe "GET conflicts" do
    it "lists the rule conflicts with an explanation and a suggested fix" do
      conflicting_rules
      sign_in(hr)

      get "#{base}/conflicts"

      entry = response.parsed_body["data"].sole
      expect(entry["explanation"]).to include("travel_under_800", "expense_over_500")
      expect(entry["fix"]).to eq("rule_key" => "travel_under_800", "new_priority" => 2)
    end
  end

  describe "POST conflict_fixes" do
    it "saves the suggested priority as a new rule version, and the conflict is gone" do
      conflicting_rules
      sign_in(hr)

      post "#{base}/conflict_fixes", params: { rule_key: "travel_under_800" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(policy.rules.where(key: "travel_under_800", status: "superseded").count).to eq(1)
      expect(policy.rules.find_by(key: "travel_under_800", status: "resolved").priority).to eq(2)
      expect(response.parsed_body["data"]).to eq([])
    end

    it "refuses a rule the report doesn't suggest a fix for" do
      conflicting_rules
      sign_in(hr)

      post "#{base}/conflict_fixes", params: { rule_key: "expense_over_500" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "is for hr_admins only" do
      conflicting_rules
      sign_in(create(:person, company: company))

      post "#{base}/conflict_fixes", params: { rule_key: "travel_under_800" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST publish" do
    it "activates the policy as its next version, with its current rules" do
      rule = create(:rule, policy: policy, status: "resolved")
      create(:rule, policy: policy, key: "old", status: "superseded")
      sign_in(hr)

      post "#{base}/publish", as: :json

      expect(response).to have_http_status(:ok)
      expect(policy.reload).to have_attributes(status: "active", version: 2)
      expect(rule.reload.status).to eq("active")
      expect(policy.rules.find_by(key: "old").status).to eq("superseded")
    end

    it "refuses while a rule still has an open question" do
      create(:rule, policy: policy, status: "extracted", ambiguities: [ ambiguity ])
      sign_in(hr)

      post "#{base}/publish", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to match(/open question/)
      expect(policy.reload.status).to eq("draft")
    end

    it "is for hr_admins only" do
      sign_in(create(:person, company: company))

      post "#{base}/publish", as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
