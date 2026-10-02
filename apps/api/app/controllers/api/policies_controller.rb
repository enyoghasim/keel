module Api
  class PoliciesController < ApplicationController
    include CompanyScoped
    include HrAdminOnly

    FIELDS = %i[id title category status version created_at].freeze

    before_action :require_current_person!, :require_hr_admin!, only: %i[conflict_fixes publish]
    before_action :set_policy, only: %i[show test conflicts conflict_fixes publish]

    def index
      render_success(data: @company.policies.map { serialize(_1) })
    end

    def show
      render_success(data: serialize(@policy).merge("rules" => @policy.rules.current.order(:id).map { RulesController.serialize(_1) }))
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
        @policy.rules.current.map(&:to_rule_definition)
      )

      render_success(data: {
        "outcome" => decision.outcome,
        "matched_rule_keys" => decision.rule_keys,
        "approvers" => decision.approvers,
        "errors" => decision.errors,
        "explanation" => decision.explanation
      })
    end

    # Conflicts between this policy's rules (SPEC.md section 7), found without a model.
    def conflicts
      render_success(data: conflict_entries)
    end

    # "Accept the suggested fix": saves the report's priority bump as a new
    # rule version. The fix is recomputed here, never taken from the client.
    def conflict_fixes
      return render_error(message: "Only a draft policy can be fixed here; change an active one with a proposal.") if @policy.status == "active"

      fix = Rules::ConflictReport.call(@policy.rules.current.map(&:to_rule_definition)).filter_map(&:fix).find { _1.rule_key == params[:rule_key] }
      return render_error(message: "There is no suggested fix for that rule.") unless fix

      rule = @policy.rules.current.find_by!(key: fix.rule_key)
      version = rule.attributes.slice("key", "conditions", "actions", "source_chunk_id", "source_quote", "ambiguities", "status").merge("priority" => fix.new_priority)
      Rule.transaction do
        rule.update!(status: "superseded")
        @policy.rules.create!(version)
      end

      render_success(data: conflict_entries)
    end

    # A policy goes live only with no open questions (SPEC.md section 7): guessing silently is how AI features lose trust.
    def publish
      open_questions = @policy.rules.current.count { _1.ambiguities.any? }
      return render_error(message: "#{open_questions} rule(s) still have an open question to answer.") if open_questions.positive?

      Policy.transaction do
        @policy.rules.current.update_all(status: "active")
        @policy.update!(status: "active", version: @policy.version + 1)
      end

      render_success(data: serialize(@policy).merge("rules" => @policy.rules.current.order(:id).map { RulesController.serialize(_1) }))
    end

    private

    def conflict_entries
      Rules::ConflictReport.call(@policy.rules.current.map(&:to_rule_definition)).map do |entry|
        entry.to_h.merge("fix" => entry.fix&.to_h)
      end.as_json
    end

    def set_policy
      @policy = @company.policies.find(params[:id])
    end

    def serialize(policy) = policy.as_json(only: FIELDS)
  end
end
