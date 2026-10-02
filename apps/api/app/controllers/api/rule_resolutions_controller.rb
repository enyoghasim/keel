module Api
  # "Pick an option" on an ambiguity banner (SPEC.md section 7). Creating a
  # resolution only records the answer and enqueues RuleResolutionJob — the
  # rewrite waits on a model, so the page follows the outcome over
  # RuleResolutionChannel. A person's own answer, so it applies directly as a
  # new rule version rather than as a proposal; only an hr_admin may answer.
  class RuleResolutionsController < ApplicationController
    include CompanyScoped
    include HrAdminOnly

    before_action :require_current_person!
    before_action :require_hr_admin!
    before_action :set_policy

    def create
      rule = @policy.rules.find(params[:rule_id])
      index = params[:ambiguity_index].to_i
      options = rule.status == "extracted" ? rule.ambiguities.dig(index, "options") : nil
      return render_error(message: "That rule has no open question to answer.") if options.nil?
      return render_error(message: "#{params[:answer].inspect} is not one of the options.") unless options.include?(params[:answer])

      resolution = @company.rule_resolutions.create!(person: current_person, rule: rule, ambiguity_index: index, answer: params[:answer])
      RuleResolutionJob.perform_later(resolution.id)
      render_success(data: resolution.as_payload, message: "Working on it.", status: :accepted)
    end

    def show
      render_success(data: @company.rule_resolutions.where(rule: @policy.rules).find(params[:id]).as_payload)
    end

    private

    def set_policy
      @policy = @company.policies.find(params[:policy_id])
    end
  end
end
