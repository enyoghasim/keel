module Api
  # The Trust page's candidate review queue (SPEC.md section 12). Production
  # signals (a thumbs-down, a rejected proposal) create candidate cases; an
  # hr_admin reviews one — fills in the expected outcome the signal can't
  # know — and adds it to its suite (status active) so the next eval run
  # includes it, or archives it.
  class EvalCasesController < ApplicationController
    include CompanyScoped

    FIELDS = %i[id suite key input expected source status notes created_at].freeze

    before_action :require_current_person!
    before_action :require_company_member!
    before_action :require_hr_admin!, only: :update

    def index
      cases = EvalCase.order(created_at: :desc, id: :desc)
      cases = cases.where(status: params[:status]) if params[:status].present?
      cases = cases.where(suite: params[:suite]) if params[:suite].present?
      render_success(data: cases.map { _1.as_json(only: FIELDS) })
    end

    def update
      eval_case = EvalCase.find(params[:id])
      attrs = {}
      attrs[:status] = params[:status] if params[:status].present?
      attrs[:expected] = params[:expected].to_unsafe_h if params[:expected].respond_to?(:to_unsafe_h)

      eval_case.assign_attributes(attrs)
      if eval_case.status == "active" && eval_case.expected.blank?
        return render_error(message: "Fill in the expected outcome before adding this case to the suite.")
      end

      eval_case.save!
      render_success(data: eval_case.as_json(only: FIELDS), message: "Case updated.")
    rescue ActiveRecord::RecordInvalid => e
      render_error(message: e.message, errors: e.record.errors.full_messages)
    end

    private

    def require_company_member!
      return if performed? || current_person.company_id == @company.id

      render_error(message: "You can only see your own company's eval cases.", status: :forbidden)
    end

    def require_hr_admin!
      return if performed? || current_person.hr_admin?

      render_error(message: "Only an hr_admin can review eval cases.", status: :forbidden)
    end
  end
end
