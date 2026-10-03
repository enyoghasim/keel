require "rails_helper"

RSpec.describe Workflows::StepValidator do
  def step(key, type: "task", assignee: "role:it_admin") = { "key" => key, "type" => type, "assignee" => assignee }

  it "accepts a workflow of well-formed steps" do
    steps = [ step("approval", type: "approval", assignee: "manager_of(requester)"), step("it"), step("hr", type: "notify", assignee: "head_of(requester.department)") ]

    expect(described_class.call(steps)).to eq([])
  end

  it "rejects two steps sharing a key" do
    expect(described_class.call([ step("it"), step("it") ])).to eq([ "step key 'it' is used more than once" ])
  end

  it "rejects an assignee that isn't a reference Org::Resolver understands — a person's name, say" do
    expect(described_class.call([ step("it", assignee: "Tunde Bakare") ])).to eq([ "step 'it' has an unknown assignee reference 'Tunde Bakare'" ])
  end

  it "accepts every reference form the resolver supports" do
    refs = [ "requester", "manager_of(requester)", "skip_manager_of(requester)", "head_of(requester.department)", "role:finance_lead" ]

    expect(described_class.call(refs.each_with_index.map { |ref, i| step("s#{i}", type: "notify", assignee: ref) })).to eq([])
  end

  it "reports every problem, not just the first" do
    errors = described_class.call([ step("a", assignee: "nobody"), step("a") ])

    expect(errors.size).to eq(2)
  end

  it "doesn't check an approval step's assignee against the reference pattern — WorkflowGenerator joins multiple approver refs there for display, and Runtime never reads it" do
    steps = [ step("approval", type: "approval", assignee: "manager_of(requester), role:finance_lead"), step("it") ]

    expect(described_class.call(steps)).to eq([])
  end

  describe ".restore_approvals" do
    let(:approval) { step("approval", type: "approval", assignee: "manager_of(requester)") }
    let(:notify) { step("hr_notify", type: "notify", assignee: "role:hr_admin") }

    # Approval steps are policy-owned (AGENTS.md rule 2) — whoever is
    # rewriting the workflow (an LLM, or now a human editor) doesn't get to
    # touch them, whatever they submit.
    it "swaps a rewritten approval step for the original of the same key" do
      submitted = [ { **approval, "assignee" => "role:ceo" }, notify ]

      expect(described_class.restore_approvals(submitted, [ approval, notify ])).to eq([ approval, notify ])
    end

    it "puts a dropped approval step back where it was" do
      expect(described_class.restore_approvals([ notify ], [ approval, notify ])).to eq([ approval, notify ])
    end

    it "drops an approval step invented out of nowhere" do
      invented = step("made_up", type: "approval", assignee: "role:ceo")

      expect(described_class.restore_approvals([ notify, invented ], [ notify ])).to eq([ notify ])
    end
  end
end
