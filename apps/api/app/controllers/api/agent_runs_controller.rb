module Api
  # The command bar's endpoint (SPEC.md section 3's request lifecycle):
  # creating a run only records the message and enqueues AgentJob, so the
  # request returns straight away and the trace arrives over AgentChannel.
  # The agent always acts as the signed-in person, and a person only sees
  # their own runs.
  class AgentRunsController < ApplicationController
    include CompanyScoped

    RECENT_LIMIT = 20

    before_action :require_current_person!
    before_action :require_company_member!

    def index
      runs = @company.agent_runs.where(person: current_person)
      runs = runs.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
      recent = runs.includes(:agent_steps).order(created_at: :desc, id: :desc).limit(RECENT_LIMIT)
      render_success(data: recent.map(&:as_payload))
    end

    def show
      agent_run = @company.agent_runs.where(person: current_person).find(params[:id])
      render_success(data: agent_run.as_payload)
    end

    def create
      agent_run = @company.agent_runs.new(person: current_person, message: params[:message].to_s.strip)
      if params[:conversation_id].present?
        return render_error(message: "That conversation doesn't exist.", status: :not_found) unless own_conversation?(params[:conversation_id])

        agent_run.conversation_id = params[:conversation_id]
      end
      return render_error(message: "Type a message first.", errors: agent_run.errors.full_messages) unless agent_run.save

      AgentJob.perform_later(agent_run.id)
      render_success(data: agent_run.as_payload, message: "Working on it.", status: :accepted)
    end

    private

    def own_conversation?(conversation_id)
      @company.agent_runs.where(person: current_person, conversation_id: conversation_id).exists?
    end

    def require_company_member!
      return if performed? || current_person.company_id == @company.id

      render_error(message: "You can only ask about your own company.", status: :forbidden)
    end
  end
end
