require "rails_helper"

RSpec.describe "Api::StepRuns", type: :request do
  def pending_step_run_needing_approval
    company = create(:company)
    manager = create(:person, company: company)
    requester = create(:person, company: company, manager: manager)
    create(:workflow, company: company, status: "active", trigger: { "request_kind" => "expense" },
                       steps: [ { "key" => "manager", "type" => "approval", "assignee" => "manager_of(requester)" } ])
    request = create(:request, company: company, requester: requester, kind: "expense", payload: { "amount_eur" => 900 })
    rule = Rules::RuleDefinition.new(
      key: "big_expense", priority: 1,
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] }
    )

    Workflows::Runtime.new(Org::GraphSnapshot.load(company)).start(request, rules: [ rule ])
    request.reload.workflow_run.step_runs.sole
  end

  describe "POST /api/step_runs/:id/act" do
    it "approves the step and finishes the workflow run, approving the request" do
      step_run = pending_step_run_needing_approval

      post "/api/step_runs/#{step_run.id}/act", params: { step_action: "approve" }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body["status"]).to eq("done")

      step_run.reload
      expect(step_run.workflow_run.reload.status).to eq("done")
      expect(step_run.workflow_run.request.reload.status).to eq("approved")
    end

    it "rejects the step, cancels the workflow run, and rejects the request" do
      step_run = pending_step_run_needing_approval

      post "/api/step_runs/#{step_run.id}/act", params: { step_action: "reject" }, as: :json

      expect(response).to have_http_status(:ok)
      step_run.reload
      expect(step_run.status).to eq("rejected")
      expect(step_run.workflow_run.request.reload.status).to eq("rejected")
    end

    it "overrides the step with a reason, approving the request despite needing approval" do
      step_run = pending_step_run_needing_approval

      post "/api/step_runs/#{step_run.id}/act", params: { step_action: "override", reason: "VP sign-off given verbally" }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body["overridden"]).to eq(true)
      expect(body["override_reason"]).to eq("VP sign-off given verbally")
      expect(step_run.workflow_run.request.reload.status).to eq("approved")
    end

    it "returns an error envelope when step_action is missing" do
      step_run = pending_step_run_needing_approval

      post "/api/step_runs/#{step_run.id}/act", params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "returns an error envelope for an unknown step_action" do
      step_run = pending_step_run_needing_approval

      post "/api/step_runs/#{step_run.id}/act", params: { step_action: "approve_twice" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns an error envelope when overriding without a reason" do
      step_run = pending_step_run_needing_approval

      post "/api/step_runs/#{step_run.id}/act", params: { step_action: "override" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns a 404 envelope for an unknown step run" do
      post "/api/step_runs/999999/act", params: { step_action: "approve" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
