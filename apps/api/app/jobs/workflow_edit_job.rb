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
    human_authored = edit.source == "steps"
    result = human_authored ? edit_from_steps(edit) : Assemble::WorkflowEditor.call(workflow: edit.workflow, instruction: edit.instruction)
    # No model wrote a human-authored edit — leave the trace column nil
    # rather than record one that was never actually called.
    model = human_authored ? nil : RubyLLM.config.default_model
    return edit.update!(status: "unchanged", model: model) unless result.changed?

    proposal = edit.company.change_proposals.create!(
      kind: "workflow", title: "#{edit.workflow.name}: #{result.summary}".truncate(120), proposed_by: "user",
      diff: { "workflow_id" => edit.workflow_id, "request_kind" => edit.workflow.trigger["request_kind"], "instruction" => edit.instruction, "before" => result.before, "after" => result.steps },
      impact: Impact::WorkflowImpact.call(company: edit.company, workflow: edit.workflow, after_steps: result.steps)
    )
    edit.update!(status: "proposed", change_proposal: proposal, model: model)
  rescue Assemble::WorkflowEditor::InvalidWorkflow, Llm::StructuredAsk::ValidationError => e
    Rails.logger.warn("[WorkflowEditJob] #{e.class}: #{e.message}")
    edit.update!(status: "failed", error_message: INVALID)
  rescue InvalidSteps => e
    Rails.logger.warn("[WorkflowEditJob] #{e.message}")
    edit.update!(status: "failed", error_message: e.message)
  rescue StandardError => e
    Rails.logger.error("[WorkflowEditJob] #{e.class}: #{e.message}")
    edit.update!(status: "failed", error_message: Llm::Failure.message_for(e, fallback: UNEXPECTED))
  end

  class InvalidSteps < StandardError; end

  # The human-authored counterpart to Assemble::WorkflowEditor: no model
  # call, but the same two rules apply — approval steps are restored
  # verbatim (AGENTS.md rule 2) and the result must pass the same
  # structural checks the AI path already does.
  def edit_from_steps(edit)
    steps = Workflows::StepValidator.restore_approvals(edit.after_steps, edit.workflow.steps)
    errors = Workflows::StepValidator.call(steps)
    raise InvalidSteps, errors.join("; ") if errors.any?

    Assemble::WorkflowEditor::Result.new(steps: steps, summary: "edited directly", before: edit.workflow.steps)
  end
end
