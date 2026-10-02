module Api
  # The command bar's endpoint (SPEC.md section 3's request lifecycle):
  # creating a run only records the message and enqueues AgentJob, so the
  # request returns straight away and the trace arrives over AgentChannel.
  # The agent always acts as the signed-in person, and a person only sees
  # their own runs.
  class AgentRunsController < ApplicationController
    include CompanyScoped

    before_action :require_current_person!
    before_action :require_company_member!

    def show
      agent_run = @company.agent_runs.where(person: current_person).find(params[:id])
      render_success(data: agent_run.as_payload)
    end

    def create
      agent_run = @company.agent_runs.new(person: current_person, message: params[:message].to_s.strip)
      return render_error(message: "Type a message first.", errors: agent_run.errors.full_messages) unless agent_run.save

      AgentJob.perform_later(agent_run.id)
      render_success(data: agent_run.as_payload, message: "Working on it.", status: :accepted)
    end

    private

    def require_company_member!
      return if performed? || current_person.company_id == @company.id

      render_error(message: "You can only ask about your own company.", status: :forbidden)
    end
  end
end
