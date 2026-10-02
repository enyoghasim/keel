require "rails_helper"

RSpec.describe "Api::PromptVersions", type: :request do
  let(:company) { create(:company) }
  let(:hr_admin) { create(:person, :hr_admin, company: company) }
  let(:base) { "/api/companies/#{company.id}/prompt_versions" }
  let!(:v1) { create(:prompt_version, version: 1, active: true, notes: "weak") }
  let!(:v2) { create(:prompt_version, version: 2, notes: "strong") }
  let(:eval_case) { create(:eval_case, suite: "policy_extraction") }

  def finish_run(version, passed, accuracy)
    run = create(:eval_run, company: company, suite: "policy_extraction", prompt_version: version, status: "completed",
      finished_at: Time.current, accuracy: accuracy, cases_count: 1, passed_count: passed ? 1 : 0)
    create(:eval_result, eval_run: run, eval_case: eval_case, passed: passed)
    run
  end

  describe "GET" do
    it "lists the versions of each prompt with their latest completed run and the cases they'd regress" do
      sign_in(hr_admin)
      finish_run(v1, true, 1.0)
      finish_run(v2, false, 0.0)

      get base

      versions = response.parsed_body["data"]
      expect(versions.map { _1["version"] }).to eq([ 2, 1 ])
      expect(versions.find { _1["version"] == 1 }).to include("active" => true, "regressions" => [])
      challenger = versions.find { _1["version"] == 2 }
      expect(challenger).to include("active" => false, "notes" => "strong", "regressions" => [ eval_case.key ])
      expect(challenger["latest_run"]).to include("accuracy" => 0.0, "suite" => "policy_extraction")
      expect(challenger).not_to have_key("template") # the list stays light; GET :show has it
    end

    it "requires sign-in" do
      get base
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET show" do
    it "includes the template" do
      sign_in(hr_admin)

      get "#{base}/#{v2.id}"

      expect(response.parsed_body["data"]).to include("template" => v2.template)
    end
  end

  describe "POST promote" do
    it "promotes a challenger that regresses nothing" do
      sign_in(hr_admin)
      finish_run(v1, true, 1.0)
      finish_run(v2, true, 1.0)

      post "#{base}/#{v2.id}/promote", as: :json

      expect(response).to have_http_status(:ok)
      expect(v2.reload).to be_active
      expect(v1.reload).not_to be_active
    end

    it "refuses a regression, naming the cases, until confirmed" do
      sign_in(hr_admin)
      finish_run(v1, true, 1.0)
      finish_run(v2, false, 0.0)

      post "#{base}/#{v2.id}/promote", as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to include(eval_case.key)
      expect(response.parsed_body["errors"]).to eq([ eval_case.key ])
      expect(v1.reload).to be_active

      post "#{base}/#{v2.id}/promote", params: { confirm: true }, as: :json
      expect(response).to have_http_status(:ok)
      expect(v2.reload).to be_active
    end

    it "is for hr_admins only" do
      sign_in(create(:person, company: company))

      post "#{base}/#{v2.id}/promote", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(v1.reload).to be_active
    end
  end
end
