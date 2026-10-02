module Api
  class PoliciesController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id title category status version created_at].freeze

    before_action :set_policy, only: %i[show test]

    def index
      render_success(data: @company.policies.map { serialize(_1) })
    end

    def show
      render_success(data: serialize(@policy).merge("rules" => @policy.rules.map { RulesController.serialize(_1) }))
    end

    # "Test this policy" (SPEC.md section 7): evaluates a scenario against
    # this policy's rules live, with Rules::Engine, no save involved.
    def test
      requester_id = params[:requester_id]
      return render_error(message: "requester_id is required") if requester_id.blank?
      return render_error(message: "requester not found in this company") unless @company.people.exists?(id: requester_id)

      snapshot = Org::GraphSnapshot.load(@company)
      decision = Rules::Engine.new(snapshot).evaluate(
        Rules::RequestInput.new(requester_id: requester_id.to_i, payload: (params[:payload] || {}).to_unsafe_h),
        @policy.rules.map(&:to_rule_definition)
      )

      render_success(data: {
        "outcome" => decision.outcome,
        "matched_rule_keys" => decision.rule_keys,
        "approvers" => decision.approvers,
        "errors" => decision.errors,
        "explanation" => decision.explanation
      })
    end

    private

    def set_policy
      @policy = @company.policies.find(params[:id])
    end

    def serialize(policy) = policy.as_json(only: FIELDS)
  end
end
