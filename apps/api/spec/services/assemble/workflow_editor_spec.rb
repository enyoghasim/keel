require "rails_helper"

RSpec.describe Assemble::WorkflowEditor do
  # SPEC.md section 8, "Describe a change": the LLM rewrites a whole
  # workflow, but only task/notify steps are its to change — the approval
  # step is whatever the policy rules say, so it is restored verbatim.
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:approval) { { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" } }
  let(:notify) { { "key" => "hr_notify", "type" => "notify", "assignee" => "role:hr_admin" } }
  let(:workflow) { create(:workflow, steps: [ approval, notify ]) }

  def message_with(content) = instance_double(RubyLLM::Message, content: content)
  def answer(steps, summary: "Added an IT step") = allow(chat).to receive(:ask).and_return(message_with({ "steps" => steps, "summary" => summary }))

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
  end

  it "returns the new steps and the model's one-line summary, without saving anything" do
    it_step = { "key" => "it_setup", "type" => "task", "assignee" => "role:it_admin", "title" => "Set up accounts" }
    answer([ approval, it_step, notify ])

    result = described_class.call(workflow: workflow, instruction: "IT sets up accounts after the manager approves")

    expect(result.steps).to eq([ approval, it_step, notify ])
    expect(result.summary).to eq("Added an IT step")
    expect(result).to be_changed
    expect(workflow.reload.steps).to eq([ approval, notify ])
  end

  it "sends the current workflow and the instruction to the model" do
    answer([ approval, notify ])

    described_class.call(workflow: workflow, instruction: "Do something")

    expect(chat).to have_received(:ask).with(a_string_including("Do something", "hr_notify", "manager_of(requester)"))
  end

  it "keeps a conditional step's when clause" do
    lagos = { "key" => "office", "type" => "notify", "assignee" => "role:office_manager", "when" => { "field" => "requester.location", "op" => "eq", "value" => "Lagos" } }
    answer([ approval, notify, lagos ])

    expect(described_class.call(workflow: workflow, instruction: "x").steps.last).to eq(lagos)
  end

  it "restores the approval step if the model rewrites its assignee" do
    answer([ { **approval, "assignee" => "role:ceo" }, notify ])

    expect(described_class.call(workflow: workflow, instruction: "x").steps).to eq([ approval, notify ])
  end

  it "puts a dropped approval step back where it was" do
    answer([ notify ])

    expect(described_class.call(workflow: workflow, instruction: "x").steps).to eq([ approval, notify ])
  end

  it "is not changed when the model returns the workflow as it was" do
    answer([ approval, notify ])

    expect(described_class.call(workflow: workflow, instruction: "x")).not_to be_changed
  end

  it "refuses a step that assigns to a person's name" do
    answer([ approval, notify, { "key" => "it", "type" => "task", "assignee" => "Tunde" } ])

    expect { described_class.call(workflow: workflow, instruction: "x") }
      .to raise_error(described_class::InvalidWorkflow, /unknown assignee reference 'Tunde'/)
  end
end
