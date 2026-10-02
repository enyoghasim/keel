require "rails_helper"

RSpec.describe Evals::AgentScorer do
  # SPEC.md section 12's agent suite, the deterministic half: did the agent
  # pick the expected tools, avoid the forbidden ones, and did the tools'
  # outputs (the outcome — not the model's wording) come out as expected?
  def call(name, output = {}, input = {}) = { "name" => name, "input" => input, "output" => output }

  let(:expected) do
    { "tools" => [ "check_policy" ], "forbidden_tools" => [ "create_request" ], "outputs" => { "check_policy" => { "decision" => "require_approval" } } }
  end

  it "passes when the expected tool ran, no forbidden one did, and its output holds the expected fields" do
    result = described_class.call(expected: expected, tool_calls: [ call("check_policy", { "decision" => "require_approval", "approvers" => [] }) ])

    expect(result).to have_attributes(passed: true, diff: [])
  end

  it "fails when an expected tool was never called" do
    result = described_class.call(expected: expected, tool_calls: [ call("search_people") ])

    expect(result.passed).to be(false)
    expect(result.diff).to include(a_hash_including("field" => "tools", "expected" => "check_policy", "actual" => [ "search_people" ]))
  end

  it "fails when a forbidden tool was called — an Ask must not file a request" do
    result = described_class.call(expected: expected, tool_calls: [ call("check_policy", { "decision" => "require_approval" }), call("create_request") ])

    expect(result.passed).to be(false)
    expect(result.diff).to include(a_hash_including("field" => "forbidden_tools", "actual" => "create_request"))
  end

  it "fails when the tool's outcome differs, comparing the last call of that tool" do
    result = described_class.call(
      expected: expected,
      tool_calls: [ call("check_policy", { "decision" => "require_approval" }), call("check_policy", { "decision" => "auto_approve" }) ]
    )

    expect(result.passed).to be(false)
    expect(result.diff).to include(a_hash_including("field" => "outputs.check_policy.decision", "expected" => "require_approval", "actual" => "auto_approve"))
  end

  it "matches nested expected fields as a subset of the tool output" do
    nested = { "tools" => [ "create_request" ], "outputs" => { "create_request" => { "steps" => [ { "assignee" => "Tunde Bakare" } ] } } }
    output = { "request_id" => 4, "steps" => [ { "step" => "approval", "status" => "pending", "assignee" => "Tunde Bakare" } ] }

    expect(described_class.call(expected: nested, tool_calls: [ call("create_request", output) ]).passed).to be(true)
  end

  it "passes a case that expects no tools at all, e.g. a greeting" do
    expect(described_class.call(expected: { "tools" => [] }, tool_calls: []).passed).to be(true)
  end
end
