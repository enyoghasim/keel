require "rails_helper"

RSpec.describe "Api::EvalCases", type: :request do
  # The Trust page's candidate review queue (SPEC.md section 12): production
  # signals create candidate cases; a reviewer fills in the expected outcome
  # and adds them to the suite, or archives them.
  let(:company) { create(:company) }
  let(:hr_admin) { create(:person, :hr_admin, company: company) }
  let(:base) { "/api/companies/#{company.id}/eval_cases" }
  let!(:candidate) do
    create(:eval_case, suite: "agent", key: "feedback_run_1", source: "generated", status: "candidate", expected: {}, notes: "Thumbs-down (wrong answer)",
      input: { "message" => "Can I expense €1,200?", "observed" => { "final_text" => "Yes." } })
  end

  describe "GET" do
    it "lists cases, filterable by status and suite, with their input, expected outcome and source" do
      sign_in(hr_admin)
      create(:eval_case, suite: "insights", status: "active")

      get base, params: { status: "candidate" }

      expect(response.parsed_body["data"].map { _1["key"] }).to eq([ "feedback_run_1" ])
      expect(response.parsed_body["data"].first).to include("suite" => "agent", "source" => "generated", "status" => "candidate",
        "notes" => "Thumbs-down (wrong answer)", "input" => a_hash_including("message" => "Can I expense €1,200?"))

      get base, params: { suite: "insights" }
      expect(response.parsed_body["data"].size).to eq(1)
    end

    it "requires sign-in" do
      get base
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH" do
    it "lets an hr_admin fill in the expected outcome and add the case to the suite" do
      sign_in(hr_admin)
      expected = { "tools" => [ "check_policy" ], "outputs" => { "check_policy" => { "decision" => "require_approval" } } }

      patch "#{base}/#{candidate.id}", params: { status: "active", expected: expected }, as: :json

      expect(response).to have_http_status(:ok)
      expect(candidate.reload).to have_attributes(status: "active", expected: expected)
    end

    it "archives a case without adding it" do
      sign_in(hr_admin)

      patch "#{base}/#{candidate.id}", params: { status: "archived" }, as: :json

      expect(candidate.reload.status).to eq("archived")
    end

    it "won't make an agent or policy case active without an expected outcome — it would fail every run" do
      sign_in(hr_admin)

      patch "#{base}/#{candidate.id}", params: { status: "active" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(candidate.reload.status).to eq("candidate")
    end

    it "rejects an unknown status" do
      sign_in(hr_admin)

      patch "#{base}/#{candidate.id}", params: { status: "deleted" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "is for hr_admins only" do
      sign_in(create(:person, company: company))

      patch "#{base}/#{candidate.id}", params: { status: "archived" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
