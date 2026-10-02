module Api
  # The prompt versions behind the Trust page (SPEC.md section 12): each
  # version with its latest completed eval run and the cases it would
  # regress against the active version, plus Promote.
  class PromptVersionsController < ApplicationController
    include CompanyScoped

    before_action :require_current_person!
    before_action :require_company_member!
    before_action :require_hr_admin!, only: :promote

    def index
      versions = PromptVersion.order(:key, version: :desc)
      render_success(data: versions.map { serialize(_1) })
    end

    def show
      prompt_version = PromptVersion.find(params[:id])
      render_success(data: serialize(prompt_version).merge("template" => prompt_version.template))
    end

    def promote
      prompt_version = PromptVersion.find(params[:id])
      Evals::Promotion.call(prompt_version: prompt_version, company: @company, confirm: ActiveModel::Type::Boolean.new.cast(params[:confirm]))
      render_success(data: serialize(prompt_version.reload), message: "Version #{prompt_version.version} is now active.")
    rescue Evals::Promotion::Blocked => e
      render_error(message: e.message, errors: e.regressions)
    end

    private

    def serialize(prompt_version)
      latest = @company.eval_runs.where(prompt_version: prompt_version, status: "completed").order(finished_at: :desc, id: :desc).first

      prompt_version.as_json(only: PromptVersion::FIELDS).merge(
        "latest_run" => latest&.as_payload,
        "regressions" => prompt_version.active? ? [] : Evals::Promotion.regressions(challenger: prompt_version, company: @company)
      )
    end

    def require_company_member!
      return if performed? || current_person.company_id == @company.id

      render_error(message: "You can only see your own company's prompt versions.", status: :forbidden)
    end

    def require_hr_admin!
      return if performed? || current_person.hr_admin?

      render_error(message: "Only an hr_admin can promote a prompt version.", status: :forbidden)
    end
  end
end
