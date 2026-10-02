module Api
  # "Describe a change" on /workflows (SPEC.md section 8). Creating an edit
  # only records the instruction and enqueues WorkflowEditJob — the editor
  # waits on a model, so the page follows the outcome over
  # WorkflowEditChannel. Like every proposal, only an hr_admin may ask.
  class WorkflowEditsController < ApplicationController
    include CompanyScoped

    before_action :require_current_person!
    before_action :require_hr_admin!
    before_action :set_workflow

    def create
      edit = @company.workflow_edits.new(workflow: @workflow, person: current_person, instruction: params[:instruction].to_s.strip)
      return render_error(message: "Describe the change first.", errors: edit.errors.full_messages) unless edit.save

      WorkflowEditJob.perform_later(edit.id)
      render_success(data: edit.as_payload, message: "Working on it.", status: :accepted)
    end

    def show
      render_success(data: @company.workflow_edits.where(workflow: @workflow).find(params[:id]).as_payload)
    end

    private

    def require_hr_admin!
      return if performed? || current_person.hr_admin?

      render_error(message: "Only an hr_admin can propose a change.", status: :forbidden)
    end

    def set_workflow
      @workflow = @company.workflows.find(params[:workflow_id])
    end
  end
end
