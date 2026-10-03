require "rails_helper"

RSpec.describe "Api::WorkflowEdits", type: :request do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:hr) { create(:person, :hr_admin, company: company) }
  let(:workflow) { create(:workflow, company: company) }

  describe "POST /api/companies/:company_id/workflows/:workflow_id/edits" do
    it "records the instruction as pending and hands it to WorkflowEditJob, without waiting on the model" do
      sign_in(hr)

      expect {
        post "/api/companies/#{company.id}/workflows/#{workflow.id}/edits", params: { instruction: "Notify the office manager" }, as: :json
      }.to have_enqueued_job(WorkflowEditJob)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body["data"]
      expect(body).to include("instruction" => "Notify the office manager", "status" => "pending", "workflow_id" => workflow.id)
      expect(WorkflowEdit.find(body["id"])).to have_attributes(company: company, person: hr)
    end

    it "accepts directly-authored steps instead of an instruction" do
      sign_in(hr)
      steps = [ { "key" => "approval", "type" => "approval" }, { "key" => "it", "type" => "task", "assignee" => "role:it_admin" } ]

      expect {
        post "/api/companies/#{company.id}/workflows/#{workflow.id}/edits", params: { steps: steps }, as: :json
      }.to have_enqueued_job(WorkflowEditJob)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body["data"]
      expect(body).to include("source" => "steps", "status" => "pending", "instruction" => nil)
      expect(WorkflowEdit.find(body["id"]).after_steps).to eq(steps)
    end

    it "rejects a blank instruction" do
      sign_in(hr)

      post "/api/companies/#{company.id}/workflows/#{workflow.id}/edits", params: { instruction: " " }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(WorkflowEdit.count).to eq(0)
    end

    it "is for hr_admins only, as proposing any change is" do
      sign_in(create(:person, company: company))

      post "/api/companies/#{company.id}/workflows/#{workflow.id}/edits", params: { instruction: "x" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "requires sign-in" do
      post "/api/companies/#{company.id}/workflows/#{workflow.id}/edits", params: { instruction: "x" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/companies/:company_id/workflows/:workflow_id/edits/:id" do
    it "returns the edit's current state" do
      sign_in(hr)
      edit = create(:workflow_edit, company: company, workflow: workflow, status: "failed", error_message: "nope")

      get "/api/companies/#{company.id}/workflows/#{workflow.id}/edits/#{edit.id}"

      expect(response.parsed_body["data"]).to include("id" => edit.id, "status" => "failed", "error_message" => "nope")
    end
  end
end
