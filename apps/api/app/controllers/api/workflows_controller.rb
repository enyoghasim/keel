module Api
  # Workflow definitions and the "Test run" preview (SPEC.md section 8):
  # test_run previews how Workflows::Runtime would resolve a request right
  # now, via Runtime#dry_run, with nothing saved.
  class WorkflowsController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id name status trigger steps created_at].freeze

    before_action :set_workflow, only: %i[show test_run]

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
        rules: active_rules_for(@workflow.trigger["request_kind"])
      )

      render_success(data: {
        "outcome" => result.outcome,
        "matched_rule_keys" => result.matched_rule_keys,
        "errors" => result.errors,
        "steps" => result.steps.map { serialize_step(_1) }
      })
    end

    private

    def set_workflow
      @workflow = @company.workflows.find(params[:id])
    end

    def active_rules_for(kind)
      @company.policies.where(status: "active", category: kind).flat_map do |policy|
        policy.rules.where(status: "active").map(&:to_rule_definition)
      end
    end

    def serialize(workflow) = workflow.as_json(only: FIELDS)

    def serialize_step(step)
      { "step_key" => step.step_key, "type" => step.type, "reference" => step.reference,
        "resolved_person_id" => step.resolved_person_id, "matched" => step.matched }
    end
  end
end
