# Turns one "Describe a change" instruction into a workflow ChangeProposal
# (SPEC.md sections 8 and 10): Assemble::WorkflowEditor rewrites the workflow
# (the only LLM step), Impact::WorkflowImpact computes what it would change,
# and a pending proposal waits for a human. Runs as a job because the editor
# waits on a model; the outcome is recorded on the WorkflowEdit and
# broadcast on WorkflowEditChannel.
class WorkflowEditJob < ApplicationJob
  INVALID = "Keel couldn't turn that into a valid workflow. Try describing the step and who does it " \
            "(for example \"IT sets up accounts after the manager approves\").".freeze
  UNEXPECTED = "Something went wrong drafting that change. Please try again.".freeze

  def perform(workflow_edit_id)
    edit = WorkflowEdit.find(workflow_edit_id)
    return unless edit.status == "pending"

    propose(edit)
    WorkflowEditChannel.broadcast_to(edit, edit.as_payload)
  end

  private

  def propose(edit)
    result = Assemble::WorkflowEditor.call(workflow: edit.workflow, instruction: edit.instruction)
    return edit.update!(status: "unchanged", model: RubyLLM.config.default_model) unless result.changed?

    proposal = edit.company.change_proposals.create!(
      kind: "workflow", title: "#{edit.workflow.name}: #{result.summary}".truncate(120), proposed_by: "user",
      diff: { "workflow_id" => edit.workflow_id, "instruction" => edit.instruction, "before" => result.before, "after" => result.steps },
      impact: Impact::WorkflowImpact.call(company: edit.company, workflow: edit.workflow, after_steps: result.steps)
    )
    edit.update!(status: "proposed", change_proposal: proposal, model: RubyLLM.config.default_model)
  rescue Assemble::WorkflowEditor::InvalidWorkflow, Llm::StructuredAsk::ValidationError => e
    Rails.logger.warn("[WorkflowEditJob] #{e.class}: #{e.message}")
    edit.update!(status: "failed", error_message: INVALID)
  rescue StandardError => e
    Rails.logger.error("[WorkflowEditJob] #{e.class}: #{e.message}")
    edit.update!(status: "failed", error_message: UNEXPECTED)
  end
end
