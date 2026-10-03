module Api
  # Workflow definitions and the "Test run" preview (SPEC.md section 8):
  # test_run previews how Workflows::Runtime would resolve a request right
  # now, via Runtime#dry_run, with nothing saved.
  class WorkflowsController < ApplicationController
    include CompanyScoped
    include HrAdminOnly

    FIELDS = %i[id name status version trigger steps created_at].freeze

    before_action :require_current_person!, :require_hr_admin!, only: %i[update publish]
    before_action :set_workflow, only: %i[show test_run update publish]

    def index
      render_success(data: @company.workflows.map { serialize(_1) })
    end

    def show
      render_success(data: serialize(@workflow))
    end

    def test_run
      requester_id = params[:requester_id]
      return render_error(message: "requester_id is required") if requester_id.blank?
      return render_error(message: "requester not found in this company") unless @company.people.exists?(id: requester_id)

      snapshot = Org::GraphSnapshot.load(@company)
      result = Workflows::Runtime.new(snapshot).dry_run(
        @workflow, requester_id: requester_id.to_i, payload: (params[:payload] || {}).to_unsafe_h,
        rules: @company.active_rule_definitions(@workflow.trigger["request_kind"])
      )

      render_success(data: {
        "outcome" => result.outcome,
        "matched_rule_keys" => result.matched_rule_keys,
        "errors" => result.errors,
        "steps" => result.steps.map { serialize_step(_1) }
      })
    end

    # Direct editing (SPEC.md section 8's editor), draft only: nothing live
    # is protected yet, so this saves straight away — no Change Proposal.
    # An active workflow is edited through workflow_edits instead, which
    # computes impact and requires approval before anything changes.
    def update
      unless @workflow.status == "draft"
        return render_error(message: "Only a draft workflow can be edited directly. Propose a change to an active one instead.", status: :forbidden)
      end

      steps = Workflows::StepValidator.restore_approvals(raw_steps, @workflow.steps)
      errors = Workflows::StepValidator.call(steps)
      return render_error(message: errors.join("; ")) if errors.any?

      @workflow.update!(steps: steps, version: @workflow.version + 1)
      render_success(data: serialize(@workflow))
    end

    # A draft workflow (built by Assemble or still being edited) never
    # runs real requests — Workflows::Runtime only looks at status:
    # "active" ones. Publishing is the one human act that turns it on.
    def publish
      @workflow.update!(status: "active", version: @workflow.version + 1)
      render_success(data: serialize(@workflow))
    end

    private

    def set_workflow
      @workflow = @company.workflows.find(params[:id])
    end

    def raw_steps = (params[:steps] || []).map(&:to_unsafe_h)

    def serialize(workflow) = workflow.as_json(only: FIELDS)

    def serialize_step(step)
      { "step_key" => step.step_key, "type" => step.type, "reference" => step.reference,
        "resolved_person_id" => step.resolved_person_id, "matched" => step.matched }
    end
  end
end
