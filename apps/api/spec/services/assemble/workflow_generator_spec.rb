require "rails_helper"

RSpec.describe Assemble::WorkflowGenerator do
  # Mirrors SPEC.md section 6, stage 5: the approval step is deterministic
  # (straight from the rules), the LLM only proposes task/notify steps.
  let(:chat) { instance_double(RubyLLM::Chat) }

  def message_with(content) = instance_double(RubyLLM::Message, content: content)
  def rule(decision:, approvers: nil) = Rules::RuleDefinition.new(key: "r", priority: 1, conditions: {}, actions: { "decision" => decision, "approvers" => approvers }.compact)

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
  end

  it "builds a draft workflow with an approval step from the rules, followed by the LLM's task/notify steps" do
    company = create(:company)
    rules = [ rule(decision: "require_approval", approvers: [ "manager_of(requester)" ]) ]
    allow(chat).to receive(:ask).and_return(message_with({
      "additional_steps" => [
        { "key" => "it", "type" => "task", "assignee" => "role:it_admin", "title" => "Order the laptop" }
      ]
    }))

    workflow = described_class.call(company: company, request_kind: "equipment", rules: rules)

    expect(workflow).to have_attributes(company: company, status: "draft", trigger: { "request_kind" => "equipment" })
    expect(workflow.steps).to eq([
      { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester)" },
      { "key" => "it", "type" => "task", "assignee" => "role:it_admin", "title" => "Order the laptop" }
    ])
  end

  it "omits the approval step entirely when no rule in the category requires approval" do
    company = create(:company)
    rules = [ rule(decision: "auto_approve") ]
    allow(chat).to receive(:ask).and_return(message_with({ "additional_steps" => [] }))

    workflow = described_class.call(company: company, request_kind: "expense", rules: rules)

    expect(workflow.steps).to eq([])
  end

  it "deduplicates approver references across multiple require_approval rules into one approval step" do
    company = create(:company)
    rules = [
      rule(decision: "require_approval", approvers: [ "manager_of(requester)" ]),
      rule(decision: "require_approval", approvers: [ "manager_of(requester)", "role:finance_lead" ])
    ]
    allow(chat).to receive(:ask).and_return(message_with({ "additional_steps" => [] }))

    workflow = described_class.call(company: company, request_kind: "expense", rules: rules)

    expect(workflow.steps).to eq([
      { "key" => "approval", "type" => "approval", "assignee" => "manager_of(requester), role:finance_lead" }
    ])
  end
end
