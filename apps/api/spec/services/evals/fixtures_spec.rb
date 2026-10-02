require "rails_helper"

RSpec.describe "fixtures/evals" do
  # The hand-written suites load cleanly and every policy_extraction case's
  # expected rules are valid against the policy-rules schema — a typo in a
  # fixture would otherwise only surface as a mysteriously failing eval.
  it "loads the policy_extraction cases with schema-valid expected rules" do
    cases = Evals::CaseLoader.call(suite: "policy_extraction")
    validator = JSONSchemer.schema(Llm::SchemaRegistry.fetch("policy-rules"))

    expect(cases.size).to be >= 12
    cases.each do |eval_case|
      rules = eval_case.expected["rules"].map { _1.merge("source_quote" => "x", "ambiguities" => []) }
      expect(validator.validate({ "rules" => rules }).to_a).to be_empty, "#{eval_case.key}: #{validator.validate({ 'rules' => rules }).map { JSONSchemer::Errors.pretty(_1) }}"
    end
  end

  it "loads the agent cases, each with a message, an acting person and expected tools" do
    cases = Evals::CaseLoader.call(suite: "agent")

    expect(cases.size).to be >= 12
    expect(cases).to all(satisfy { _1.input["message"].present? && _1.input["person_email"].present? && _1.expected.key?("tools") })
    labelled = cases.count { _1.expected["judge_label"] }
    expect(labelled).to be >= 5
  end
end
