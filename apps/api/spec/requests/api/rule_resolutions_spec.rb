require "rails_helper"

RSpec.describe "Api::RuleResolutions", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:hr) { create(:person, :hr_admin, company: company) }
  let(:policy) { create(:policy, company: company, status: "draft") }
  let(:ambiguity) { { "phrase" => "up to €1,000", "question" => "Travel too?", "options" => [ "Ticket only", "Everything" ] } }
  let(:rule) { create(:rule, policy: policy, status: "extracted", ambiguities: [ ambiguity ]) }
  let(:path) { "/api/companies/#{company.id}/policies/#{policy.id}/rule_resolutions" }

  describe "POST rule_resolutions" do
    it "records the answer as pending and hands it to RuleResolutionJob, without waiting on the model" do
      sign_in(hr)

      expect {
        post path, params: { rule_id: rule.id, ambiguity_index: 0, answer: "Ticket only" }, as: :json
      }.to have_enqueued_job(RuleResolutionJob)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["data"]).to include("status" => "pending", "answer" => "Ticket only", "rule_id" => rule.id)
      expect(RuleResolution.last).to have_attributes(company: company, person: hr, rule: rule)
    end

    it "refuses an answer that is not one of the rule's options" do
      sign_in(hr)

      expect { post path, params: { rule_id: rule.id, ambiguity_index: 0, answer: "Whatever" }, as: :json }
        .not_to have_enqueued_job(RuleResolutionJob)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses a rule with nothing open, such as one already resolved or superseded" do
      sign_in(hr)
      rule.update!(status: "superseded")

      post path, params: { rule_id: rule.id, ambiguity_index: 0, answer: "Ticket only" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses a rule of another policy" do
      sign_in(hr)
      other = create(:rule, policy: create(:policy, company: company), ambiguities: [ ambiguity ])

      post path, params: { rule_id: other.id, ambiguity_index: 0, answer: "Ticket only" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "is for hr_admins only" do
      sign_in(create(:person, company: company))

      post path, params: { rule_id: rule.id, ambiguity_index: 0, answer: "Ticket only" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "requires sign-in" do
      post path, params: { rule_id: rule.id, ambiguity_index: 0, answer: "Ticket only" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET rule_resolutions/:id" do
    it "returns the resolution's current state with both versions once it has finished" do
      sign_in(hr)
      resolution = create(:rule_resolution, company: company, rule: rule, answer: "Ticket only")
      new_rule = create(:rule, policy: policy, key: rule.key, status: "resolved")
      resolution.update!(status: "resolved", new_rule: new_rule)

      get "#{path}/#{resolution.id}"

      body = response.parsed_body["data"]
      expect(body).to include("status" => "resolved")
      expect(body["before"]["id"]).to eq(rule.id)
      expect(body["after"]["id"]).to eq(new_rule.id)
    end
  end
end
