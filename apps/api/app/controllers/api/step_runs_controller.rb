module Api
  # Advances a step run through Workflows::Runtime#act (SPEC.md section 8):
  # approve/complete move to the next step, reject cancels the rest of the
  # run, and override lets an approver flip the engine's decision with a
  # required reason, which feeds the eval loop later.
  class StepRunsController < ApplicationController
    STEP_ACTIONS = %w[approve reject complete override].freeze

    FIELDS = %i[id workflow_run_id step_key reference resolved_person_id status acted_at overridden override_reason].freeze

    before_action :set_step_run

    def act
      step_action = params[:step_action]
      return render_error(message: "step_action is required") if step_action.blank?
      return render_error(message: "unknown step_action '#{step_action}'") unless STEP_ACTIONS.include?(step_action)
      return render_error(message: "reason is required for an override") if step_action == "override" && params[:reason].blank?

      company = @step_run.workflow_run.request.company
      snapshot = Org::GraphSnapshot.load(company)
      Workflows::Runtime.new(snapshot).act(@step_run, action: step_action, reason: params[:reason])

      render_success(data: serialize(@step_run.reload), message: "Step updated.")
    end

    private

    def set_step_run
      @step_run = StepRun.find(params[:id])
    end

    def serialize(step_run) = step_run.as_json(only: FIELDS)
  end
end
