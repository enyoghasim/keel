require "rails_helper"

RSpec.describe "Api::ChangeProposals", type: :request do
  describe "POST /api/companies/:company_id/change_proposals" do
    it "computes the org impact and stores a pending proposal" do
      company = create(:company)
      tunde = create(:person, company: company)
      ada = create(:person, company: company)
      ngozi = create(:person, company: company, manager: tunde)

      post "/api/companies/#{company.id}/change_proposals", params: {
        kind: "org", title: "Move Ngozi under Ada",
        diff: [ { op: "change_manager", person_id: ngozi.id, to: ada.id } ]
      }, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body["data"]
      expect(body["status"]).to eq("pending")
      expect(body["diff"]).to eq([ { "op" => "change_manager", "person_id" => ngozi.id, "to" => ada.id } ])
      # One rerouted classification per representative scenario (3 expense + 1 leave).
      expect(body["impact"]["rerouted"].size).to eq(4)
      expect(body["impact"]["rerouted"].map { _1["person_id"] }.uniq).to eq([ ngozi.id ])
      expect(body["impact"]["broken"]).to eq([])
    end

    it "returns an error envelope when kind is missing" do
      company = create(:company)

      post "/api/companies/#{company.id}/change_proposals", params: { title: "x", diff: [] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
    end

    it "returns an error envelope for a kind that isn't supported yet" do
      company = create(:company)

      post "/api/companies/#{company.id}/change_proposals",
        params: { kind: "rule", title: "x", diff: [] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
    end
  end

  describe "GET /api/companies/:company_id/change_proposals/:id" do
    it "returns the proposal with its stored diff and impact" do
      company = create(:company)
      change_proposal = create(:change_proposal, company: company)

      get "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}"

      body = response.parsed_body["data"]
      expect(body["id"]).to eq(change_proposal.id)
      expect(body["diff"]).to eq(change_proposal.diff)
      expect(body["impact"]).to eq(change_proposal.impact)
    end
  end

  describe "GET /api/companies/:company_id/change_proposals" do
    it "lists only this company's proposals, optionally filtered by status" do
      company = create(:company)
      pending = create(:change_proposal, company: company, status: "pending")
      approved = create(:change_proposal, company: company, status: "approved")
      create(:change_proposal) # a different company's proposal, must not show up

      get "/api/companies/#{company.id}/change_proposals"
      expect(response.parsed_body["data"].map { _1["id"] }).to contain_exactly(pending.id, approved.id)

      get "/api/companies/#{company.id}/change_proposals", params: { status: "approved" }
      expect(response.parsed_body["data"].map { _1["id"] }).to eq([ approved.id ])
    end
  end

  describe "POST /api/companies/:company_id/change_proposals/:id/approve" do
    it "applies the diff to the real records and marks the proposal approved" do
      company = create(:company)
      old_manager = create(:person, company: company)
      new_manager = create(:person, company: company)
      person = create(:person, company: company, manager: old_manager)
      hr = create(:person, company: company)
      change_proposal = create(:change_proposal, company: company, status: "pending",
        diff: [ { "op" => "change_manager", "person_id" => person.id, "to" => new_manager.id } ],
        impact: { "rerouted" => [], "broken" => [], "self_approval" => [], "approval_load_changes" => [], "rerouted_in_flight" => [] })

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve",
        params: { decided_by_id: hr.id }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body["status"]).to eq("approved")
      expect(body["decided_by_id"]).to eq(hr.id)
      expect(body["decided_at"]).to be_present
      expect(person.reload.manager_id).to eq(new_manager.id)
    end

    it "refuses when the impact has gotten materially worse since the proposal was made" do
      company = create(:company)
      sales = create(:department, company: company)
      head = create(:person, company: company)
      sales.update!(head: head)
      requester = create(:person, company: company, department: sales)
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "needs_head_approval",
                     conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 1000 },
                     actions: { "decision" => "require_approval", "approvers" => [ "head_of(requester.department)" ] })
      change_proposal = create(:change_proposal, company: company, status: "pending",
        diff: [ { "op" => "set_department_head", "department_id" => sales.id, "to" => nil } ],
        impact: { "rerouted" => [], "broken" => [], "self_approval" => [], "approval_load_changes" => [], "rerouted_in_flight" => [] })

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["success"]).to eq(false)
      expect(change_proposal.reload.status).to eq("pending")
      expect(sales.reload.head_id).to eq(head.id)
    end

    it "approves anyway when approve_anyway is passed with a reason, despite the worse impact" do
      company = create(:company)
      sales = create(:department, company: company)
      head = create(:person, company: company)
      sales.update!(head: head)
      requester = create(:person, company: company, department: sales)
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "needs_head_approval",
                     conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 1000 },
                     actions: { "decision" => "require_approval", "approvers" => [ "head_of(requester.department)" ] })
      change_proposal = create(:change_proposal, company: company, status: "pending",
        diff: [ { "op" => "set_department_head", "department_id" => sales.id, "to" => nil } ],
        impact: { "rerouted" => [], "broken" => [], "self_approval" => [], "approval_load_changes" => [], "rerouted_in_flight" => [] })

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve",
        params: { approve_anyway: true, reason: "Sales is being folded into Ops next week anyway" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(change_proposal.reload.status).to eq("approved")
      expect(sales.reload.head_id).to be_nil
      expect(change_proposal.impact["override_reason"]).to eq("Sales is being folded into Ops next week anyway")
    end

    it "requires a reason when approving anyway" do
      company = create(:company)
      change_proposal = create(:change_proposal, company: company, status: "pending")

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve",
        params: { approve_anyway: true }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(change_proposal.reload.status).to eq("pending")
    end

    it "refuses to re-decide a proposal that's already been decided" do
      company = create(:company)
      change_proposal = create(:change_proposal, company: company, status: "approved")

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve", as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/companies/:company_id/change_proposals/:id/reject" do
    it "records the decision without applying the diff" do
      company = create(:company)
      old_manager = create(:person, company: company)
      new_manager = create(:person, company: company)
      person = create(:person, company: company, manager: old_manager)
      hr = create(:person, company: company)
      change_proposal = create(:change_proposal, company: company, status: "pending",
        diff: [ { "op" => "change_manager", "person_id" => person.id, "to" => new_manager.id } ])

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/reject",
        params: { decided_by_id: hr.id }, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body["status"]).to eq("rejected")
      expect(body["decided_by_id"]).to eq(hr.id)
      expect(person.reload.manager_id).to eq(old_manager.id)
    end
  end
end
