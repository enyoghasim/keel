module Api
  # /insights (SPEC.md section 11). Creating a question only records it and
  # enqueues InsightJob — the Interpreter waits on a model, so the page
  # follows the outcome over InsightChannel instead of this request.
  class InsightsController < ApplicationController
    include CompanyScoped

    RECENT_LIMIT = 10

    before_action :require_current_person!
    before_action :require_company_member!

    def index
      recent = @company.insight_queries.where(person: current_person).order(created_at: :desc).limit(RECENT_LIMIT)
      render_success(data: recent.map(&:as_payload))
    end

    def show
      render_success(data: @company.insight_queries.find(params[:id]).as_payload)
    end

    def create
      insight_query = @company.insight_queries.new(person: current_person, question: params[:question].to_s.strip)
      return render_error(message: "Ask a question first.", errors: insight_query.errors.full_messages) unless insight_query.save

      InsightJob.perform_later(insight_query.id)
      render_success(data: insight_query.as_payload, message: "Working on it.", status: :accepted)
    end

    private

    def require_company_member!
      return if performed? || current_person.company_id == @company.id

      render_error(message: "You can only ask about your own company.", status: :forbidden)
    end
  end
end
