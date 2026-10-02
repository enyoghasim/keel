require "rails_helper"

RSpec.describe Agent::Feedback do
  # SPEC.md section 9's Feedback and section 12's production feedback loop:
  # a thumbs-down becomes a candidate agent eval case holding the message,
  # the trace and the user's note, for a reviewer to turn into a test.
  let(:company) { create(:company) }
  let(:person) { create(:person, company: company) }
  let(:agent_run) do
    create(:agent_run, company: company, person: person, status: "completed", message: "Can I expense a €1,200 flight?", final_text: "Yes, auto-approved.")
  end

  before do
    agent_run.agent_steps.create!(position: 1, kind: "llm", output: { "tool_calls" => [ { "name" => "check_policy", "arguments" => { "request_kind" => "expense" } } ] })
    agent_run.agent_steps.create!(position: 2, kind: "tool", tool_name: "check_policy", input: { "request_kind" => "expense" }, output: { "decision" => "require_approval" })
  end

  it "records a thumbs-up on the run without creating a case" do
    described_class.call(agent_run: agent_run, rating: "up")

    expect(agent_run.reload).to have_attributes(feedback: "up", feedback_reason: nil)
    expect(EvalCase.count).to eq(0)
  end

  it "turns a thumbs-down into a candidate agent case with the message, the trace and the note" do
    described_class.call(agent_run: agent_run, rating: "down", reason: "wrong_answer", note: "It needs manager approval.")

    expect(agent_run.reload).to have_attributes(feedback: "down", feedback_reason: "wrong_answer", feedback_note: "It needs manager approval.")
    eval_case = EvalCase.sole
    expect(eval_case).to have_attributes(suite: "agent", source: "generated", status: "candidate", key: "feedback_run_#{agent_run.id}")
    expect(eval_case.input).to include("message" => "Can I expense a €1,200 flight?", "person_id" => person.id, "agent_run_id" => agent_run.id)
    expect(eval_case.input["observed"]).to eq(
      "final_text" => "Yes, auto-approved.",
      "tool_calls" => [ { "name" => "check_policy", "input" => { "request_kind" => "expense" }, "output" => { "decision" => "require_approval" } } ]
    )
    expect(eval_case.expected).to eq({})
    expect(eval_case.notes).to eq("Thumbs-down (wrong answer): It needs manager approval.")
  end

  it "updates the same candidate when the person changes their note, rather than adding another" do
    described_class.call(agent_run: agent_run, rating: "down", reason: "unclear")
    described_class.call(agent_run: agent_run, rating: "down", reason: "wrong_action", note: "It filed it.")

    expect(EvalCase.count).to eq(1)
    expect(EvalCase.sole.notes).to eq("Thumbs-down (wrong action): It filed it.")
  end

  it "archives a still-pending candidate if the person changes their mind to thumbs-up" do
    described_class.call(agent_run: agent_run, rating: "down", reason: "unclear")
    described_class.call(agent_run: agent_run, rating: "up")

    expect(agent_run.reload.feedback_reason).to be_nil
    expect(EvalCase.sole.status).to eq("archived")
  end

  it "leaves a case a reviewer already made active alone" do
    described_class.call(agent_run: agent_run, rating: "down", reason: "unclear")
    EvalCase.sole.update!(status: "active")
    described_class.call(agent_run: agent_run, rating: "up")

    expect(EvalCase.sole.status).to eq("active")
  end

  it "rejects an unknown rating or reason" do
    expect { described_class.call(agent_run: agent_run, rating: "meh") }.to raise_error(ArgumentError, /rating/)
    expect { described_class.call(agent_run: agent_run, rating: "down", reason: "boring") }.to raise_error(ArgumentError, /reason/)
  end

  it "only takes feedback on a finished answer" do
    agent_run.update!(status: "running")

    expect { described_class.call(agent_run: agent_run, rating: "up") }.to raise_error(ArgumentError, /finished/)
  end
end
