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

    it "includes the agent run that proposed it, so the UI can link to the trace" do
      company = create(:company)
      agent_run = create(:agent_run, company: company)
      change_proposal = create(:change_proposal, company: company, agent_run: agent_run, proposed_by: "agent")

      get "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}"

      expect(response.parsed_body["data"]["agent_run_id"]).to eq(agent_run.id)
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
      hr = create(:person, :hr_admin, company: company)
      change_proposal = create(:change_proposal, company: company, status: "pending",
        diff: [ { "op" => "change_manager", "person_id" => person.id, "to" => new_manager.id } ],
        impact: { "rerouted" => [], "broken" => [], "self_approval" => [], "approval_load_changes" => [], "rerouted_in_flight" => [] })
      sign_in(hr)

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve", as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body["status"]).to eq("approved")
      expect(body["decided_by_id"]).to eq(hr.id)
      expect(body["decided_at"]).to be_present
      expect(person.reload.manager_id).to eq(new_manager.id)
    end

    it "records the signed-in person as the decider, ignoring any decided_by_id param" do
      company = create(:company)
      old_manager = create(:person, company: company)
      new_manager = create(:person, company: company)
      person = create(:person, company: company, manager: old_manager)
      hr = create(:person, :hr_admin, company: company)
      impersonated = create(:person, company: company)
      change_proposal = create(:change_proposal, company: company, status: "pending",
        diff: [ { "op" => "change_manager", "person_id" => person.id, "to" => new_manager.id } ],
        impact: { "rerouted" => [], "broken" => [], "self_approval" => [], "approval_load_changes" => [], "rerouted_in_flight" => [] })
      sign_in(hr)

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve",
        params: { decided_by_id: impersonated.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]["decided_by_id"]).to eq(hr.id)
    end

    context "when the agent proposed it" do
      # SPEC.md sections 10 and 12: a rejection with a reason becomes a
      # candidate case for the agent suite — the agent proposed something a
      # human didn't want.
      let(:company) { create(:company) }
      let(:hr) { create(:person, :hr_admin, company: company) }
      let(:agent_run) { create(:agent_run, company: company, person: hr, status: "completed", message: "Make Ada head of Sales", final_text: "Proposed it.") }
      let(:proposal) { create(:change_proposal, company: company, proposed_by: "agent", agent_run: agent_run, title: "Ada heads Sales") }

      before { sign_in(hr) }

      it "records the reason and creates a candidate agent case holding the message, the trace and the proposal" do
        post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/reject", params: { reason: "Ada is on leave" }, as: :json

        expect(response).to have_http_status(:ok)
        expect(proposal.reload.impact["rejection_reason"]).to eq("Ada is on leave")
        eval_case = EvalCase.sole
        expect(eval_case).to have_attributes(suite: "agent", source: "generated", status: "candidate", key: "rejected_proposal_#{proposal.id}")
        expect(eval_case.input).to include("message" => "Make Ada head of Sales", "agent_run_id" => agent_run.id,
          "proposal" => a_hash_including("title" => "Ada heads Sales", "kind" => "org"))
        expect(eval_case.notes).to eq("Proposal rejected: Ada is on leave")
      end

      it "creates nothing without a reason, since there's no signal about what was wrong" do
        post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/reject", as: :json

        expect(response).to have_http_status(:ok)
        expect(EvalCase.count).to eq(0)
      end

      it "creates nothing for a proposal a person made themselves" do
        manual = create(:change_proposal, company: company, proposed_by: "user")

        post "/api/companies/#{company.id}/change_proposals/#{manual.id}/reject", params: { reason: "No" }, as: :json

        expect(EvalCase.count).to eq(0)
      end
    end

    it "returns a 401 envelope when no one is signed in" do
      company = create(:company)
      change_proposal = create(:change_proposal, company: company, status: "pending")

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve", as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(change_proposal.reload.status).to eq("pending")
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
      sign_in(create(:person, :hr_admin, company: company))

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
      sign_in(create(:person, :hr_admin, company: company))

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
      sign_in(create(:person, :hr_admin, company: company))

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve",
        params: { approve_anyway: true }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(change_proposal.reload.status).to eq("pending")
    end

    it "refuses to re-decide a proposal that's already been decided" do
      company = create(:company)
      change_proposal = create(:change_proposal, company: company, status: "approved")
      sign_in(create(:person, :hr_admin, company: company))

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/approve", as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "approving a rule proposal" do
    let(:company) { create(:company) }
    let(:hr) { create(:person, company: company, roles: [ "hr_admin" ]) }
    let(:employee) { create(:person, company: company, manager: hr) }
    let(:policy) { create(:policy, company: company, category: "expense", status: "active") }
    let!(:rule) do
      create(:rule, policy: policy, status: "active", key: "expense_small_auto", priority: 10,
        conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 500 }, actions: { "decision" => "auto_approve" })
    end
    let(:rule_json) { { "key" => rule.key, "priority" => 10, "source_quote" => rule.source_quote, "source_chunk_id" => rule.source_chunk_id } }
    let(:diff) do
      {
        "policy_id" => policy.id, "instruction" => "Raise the limit to €800",
        "before" => [ rule_json.merge("conditions" => rule.conditions, "actions" => rule.actions) ],
        "after" => [ rule_json.merge("conditions" => { "field" => "payload.amount_eur", "op" => "lte", "value" => 800 }, "actions" => rule.actions) ]
      }
    end
    let(:proposal) { create(:change_proposal, company: company, kind: "rule", diff: diff, impact: { "backtest" => { "total" => 0 } }) }

    before do
      create(:request, company: company, requester: employee, kind: "expense", payload: { "amount_eur" => 700 })
      sign_in(hr)
    end

    it "supersedes the old rule with the new one, bumps the policy version and re-runs the backtest" do
      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/approve", as: :json

      expect(response).to have_http_status(:ok)
      expect(proposal.reload).to have_attributes(status: "approved", decided_by_id: hr.id)
      expect(proposal.impact["backtest"]).to include("total" => 1, "flipped_count" => 1)
      expect(rule.reload.status).to eq("superseded")
      current = policy.rules.find_by!(key: "expense_small_auto", status: "active")
      expect(current.conditions["value"]).to eq(800)
      expect(current).to have_attributes(source_quote: rule.source_quote, source_chunk_id: rule.source_chunk_id)
      expect(policy.reload.version).to eq(2)
    end

    it "refuses when the policy's rules changed since the proposal was made" do
      proposal # built against the 500 limit
      rule.update!(conditions: { "field" => "payload.amount_eur", "op" => "lte", "value" => 400 })

      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/approve", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to match(/changed since/)
      expect(proposal.reload.status).to eq("pending")
      expect(rule.reload.status).to eq("active")
    end
  end

  describe "approving a workflow proposal" do
    let(:company) { create(:company) }
    let(:hr) { create(:person, company: company, roles: [ "hr_admin" ]) }
    let(:approval) { { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" } }
    let(:workflow) { create(:workflow, company: company, steps: [ approval ]) }
    let(:it_step) { { "key" => "it_setup", "type" => "task", "assignee" => "role:it_admin" } }
    let(:diff) { { "workflow_id" => workflow.id, "instruction" => "IT sets up accounts", "before" => [ approval ], "after" => [ approval, it_step ] } }
    let(:proposal) { create(:change_proposal, company: company, kind: "workflow", diff: diff, impact: { "broken" => [] }) }

    before do
      create(:person, company: company, manager: hr)
      sign_in(hr)
    end

    it "replaces the workflow's steps, bumps its version and re-runs the impact" do
      create(:person, company: company, manager: hr, roles: [ "it_admin" ])

      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/approve", as: :json

      expect(response).to have_http_status(:ok)
      expect(proposal.reload).to have_attributes(status: "approved", decided_by_id: hr.id)
      expect(proposal.impact["steps"]).to include("added" => [ "it_setup" ])
      expect(workflow.reload).to have_attributes(steps: [ approval, it_step ], version: 2)
    end

    it "refuses when the workflow changed since the proposal was made" do
      proposal
      workflow.update!(steps: [ approval, { "key" => "other", "type" => "notify", "assignee" => "role:hr_admin" } ])

      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/approve", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to match(/changed since/)
      expect(proposal.reload.status).to eq("pending")
    end

    it "refuses when the impact got worse, unless approved anyway with a reason" do
      # Nobody holds role:it_admin now, though the proposal was made when someone did.
      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/approve", as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to match(/impact has gotten worse/)
      expect(workflow.reload.steps).to eq([ approval ])

      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/approve",
        params: { approve_anyway: true, reason: "IT admin starts Monday" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(proposal.reload.impact["override_reason"]).to eq("IT admin starts Monday")
      expect(workflow.reload.steps).to eq([ approval, it_step ])
    end
  end

  describe "GET /api/companies/:company_id/change_proposals/:id/trace" do
    let(:company) { create(:company) }
    let(:asker) { create(:person, :hr_admin, company: company) }
    let(:agent_run) { create(:agent_run, company: company, person: asker, status: "completed", final_text: "Proposed.") }
    let(:proposal) { create(:change_proposal, company: company, proposed_by: "agent", agent_run: agent_run) }

    before { create(:agent_step, agent_run: agent_run, position: 1, kind: "tool", tool_name: "propose_org_change") }

    it "lets any hr_admin reviewer open the agent run that proposed it, though the run is someone else's" do
      sign_in(create(:person, :hr_admin, company: company))

      get "/api/companies/#{company.id}/change_proposals/#{proposal.id}/trace"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include("id" => agent_run.id, "person_id" => asker.id)
      expect(response.parsed_body["data"]["steps"].first).to include("tool_name" => "propose_org_change")
    end

    it "is for the people who may decide the proposal, not anyone in the company" do
      sign_in(create(:person, company: company))

      get "/api/companies/#{company.id}/change_proposals/#{proposal.id}/trace"

      expect(response).to have_http_status(:forbidden)
    end

    it "is not found for a proposal a person made without the agent" do
      sign_in(create(:person, :hr_admin, company: company))
      manual = create(:change_proposal, company: company)

      get "/api/companies/#{company.id}/change_proposals/#{manual.id}/trace"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "who may decide" do
    it "forbids anyone but an hr_admin from approving or rejecting, leaving the proposal pending" do
      company = create(:company)
      proposal = create(:change_proposal, company: company, status: "pending")
      sign_in(create(:person, company: company))

      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/approve", as: :json
      expect(response).to have_http_status(:forbidden)

      post "/api/companies/#{company.id}/change_proposals/#{proposal.id}/reject", as: :json
      expect(response).to have_http_status(:forbidden)
      expect(proposal.reload.status).to eq("pending")
    end
  end

  describe "POST /api/companies/:company_id/change_proposals/:id/reject" do
    it "records the decision without applying the diff" do
      company = create(:company)
      old_manager = create(:person, company: company)
      new_manager = create(:person, company: company)
      person = create(:person, company: company, manager: old_manager)
      hr = create(:person, :hr_admin, company: company)
      change_proposal = create(:change_proposal, company: company, status: "pending",
        diff: [ { "op" => "change_manager", "person_id" => person.id, "to" => new_manager.id } ])
      sign_in(hr)

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/reject", as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["data"]
      expect(body["status"]).to eq("rejected")
      expect(body["decided_by_id"]).to eq(hr.id)
      expect(person.reload.manager_id).to eq(old_manager.id)
    end

    it "returns a 401 envelope when no one is signed in" do
      company = create(:company)
      change_proposal = create(:change_proposal, company: company, status: "pending")

      post "/api/companies/#{company.id}/change_proposals/#{change_proposal.id}/reject", as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(change_proposal.reload.status).to eq("pending")
    end
  end
end
