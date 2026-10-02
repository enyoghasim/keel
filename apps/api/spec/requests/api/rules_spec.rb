require "rails_helper"

RSpec.describe "Api::Rules", type: :request do
  describe "GET /api/companies/:company_id/policies/:policy_id/rules" do
    it "lists the policy's rules" do
      company = create(:company)
      policy = create(:policy, company: company)
      rule = create(:rule, policy: policy)
      create(:rule) # a different policy's rule, must not show up

      get "/api/companies/#{company.id}/policies/#{policy.id}/rules"

      ids = response.parsed_body["data"].map { _1["id"] }
      expect(ids).to eq([ rule.id ])
    end
  end

  describe "GET /api/companies/:company_id/policies/:policy_id/rules/:id" do
    it "returns the rule" do
      company = create(:company)
      policy = create(:policy, company: company)
      rule = create(:rule, policy: policy)

      get "/api/companies/#{company.id}/policies/#{policy.id}/rules/#{rule.id}"

      body = response.parsed_body["data"]
      expect(body).to include("id" => rule.id, "key" => rule.key, "source_quote" => rule.source_quote)
    end

    it "returns a 404 envelope for a rule belonging to a different policy" do
      company = create(:company)
      policy = create(:policy, company: company)
      other_rule = create(:rule)

      get "/api/companies/#{company.id}/policies/#{policy.id}/rules/#{other_rule.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
