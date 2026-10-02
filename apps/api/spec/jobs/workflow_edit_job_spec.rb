require "rails_helper"

RSpec.describe WorkflowEditJob, type: :job do
  include ActionCable::TestHelper

  # Assemble::WorkflowEditor and Impact::WorkflowImpact have their own specs;
  # this job runs them in turn off the request thread, records a pending
  # ChangeProposal (never an applied change — AGENTS.md rule 2) and
  # broadcasts the outcome. The editor (the LLM) is stubbed.
  let(:company) { create(:company) }
  let(:approval) { { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" } }
  let(:it_step) { { "key" => "it_setup", "type" => "task", "assignee" => "role:it_admin" } }
  let(:workflow) { create(:workflow, company: company, steps: [ approval ]) }
  let(:edit) { create(:workflow_edit, company: company, workflow: workflow) }

  def edited(steps, summary: "Added IT setup")
    allow(Assemble::WorkflowEditor).to receive(:call).and_return(Assemble::WorkflowEditor::Result.new(steps: steps, summary: summary, before: workflow.steps))
  end

  it "records a pending proposal with the step diff and impact, and leaves the workflow alone" do
    edited([ approval, it_step ])

    described_class.perform_now(edit.id)

    proposal = ChangeProposal.last
    expect(edit.reload).to have_attributes(status: "proposed", change_proposal: proposal, model: RubyLLM.config.default_model)
    expect(proposal).to have_attributes(kind: "workflow", status: "pending", proposed_by: "user", title: "#{workflow.name}: Added IT setup")
    expect(proposal.diff).to eq("workflow_id" => workflow.id, "request_kind" => "expense", "instruction" => edit.instruction, "before" => [ approval ], "after" => [ approval, it_step ])
    expect(proposal.impact["steps"]).to include("added" => [ "it_setup" ])
    expect(workflow.reload.steps).to eq([ approval ])
    expect(Assemble::WorkflowEditor).to have_received(:call).with(workflow: workflow, instruction: edit.instruction)
  end

  it "broadcasts the outcome" do
    edited([ approval, it_step ])

    expect { described_class.perform_now(edit.id) }.to have_broadcasted_to(edit).from_channel(WorkflowEditChannel)
      .with(hash_including("status" => "proposed"))
  end

  it "says so, with no proposal, when the instruction changes nothing" do
    edited([ approval ])

    described_class.perform_now(edit.id)

    expect(edit.reload).to have_attributes(status: "unchanged", change_proposal: nil)
    expect(ChangeProposal.count).to eq(0)
  end

  it "fails with a plain message when the model's workflow is invalid" do
    allow(Assemble::WorkflowEditor).to receive(:call).and_raise(Assemble::WorkflowEditor::InvalidWorkflow, "step 'x' has an unknown assignee reference 'Tunde'")

    described_class.perform_now(edit.id)

    expect(edit.reload).to have_attributes(status: "failed", error_message: a_string_including("couldn't turn that into a valid workflow"))
    expect(ChangeProposal.count).to eq(0)
  end

  it "fails with a retry message on anything unexpected" do
    allow(Assemble::WorkflowEditor).to receive(:call).and_raise("boom")

    described_class.perform_now(edit.id)

    expect(edit.reload).to have_attributes(status: "failed", error_message: described_class::UNEXPECTED)
  end

  it "skips an edit that isn't pending" do
    edit.update!(status: "failed")
    allow(Assemble::WorkflowEditor).to receive(:call)

    described_class.perform_now(edit.id)

    expect(Assemble::WorkflowEditor).not_to have_received(:call)
  end
end
