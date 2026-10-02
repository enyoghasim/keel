module Api
  # Eval runs for the Trust page (SPEC.md section 12). Creating one only
  # records it and enqueues EvalRunJob — every case waits on a model, so the
  # page follows progress over EvalChannel.
  class EvalRunsController < ApplicationController
    include CompanyScoped

    RECENT_LIMIT = 20

    before_action :require_current_person!
    before_action :require_company_member!
    before_action :require_hr_admin!, only: :create

    def index
      runs = @company.eval_runs.order(created_at: :desc).limit(RECENT_LIMIT)
      runs = runs.where(suite: params[:suite]) if params[:suite].present?

      render_success(data: runs.map(&:as_payload), meta: {
        active_cases: EvalCase.active.group(:suite).count,
        runnable_suites: Evals::Runner::SUITES.keys
      })
    end

    def show
      eval_run = @company.eval_runs.find(params[:id])
      results = eval_run.eval_results.includes(:eval_case).order("eval_cases.key")
      render_success(data: eval_run.as_payload.merge("results" => results.map(&:as_payload)))
    end

    def create
      suite = params[:suite].to_s
      unless Evals::Runner::SUITES.key?(suite)
        return render_error(message: "The #{suite} suite can't be run yet. Runnable suites: #{Evals::Runner::SUITES.keys.join(', ')}.")
      end

      eval_run = @company.eval_runs.create!(suite: suite, person: current_person)
      EvalRunJob.perform_later(eval_run.id)
      render_success(data: eval_run.as_payload, message: "Eval run started.", status: :accepted)
    end

    private

    def require_company_member!
      return if performed? || current_person.company_id == @company.id

      render_error(message: "You can only see your own company's eval runs.", status: :forbidden)
    end

    def require_hr_admin!
      return if performed? || current_person.hr_admin?

      render_error(message: "Only an hr_admin can start an eval run.", status: :forbidden)
    end
  end
end
