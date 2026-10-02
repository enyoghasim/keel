require "rails_helper"

RSpec.describe Evals::OverrideCandidate do
  # SPEC.md section 12: an approver overriding an engine decision (with a
  # reason) is a production signal that a rule may be wrong, so it becomes a
  # candidate policy_extraction case: the handbook text behind the rules that
  # decided it, for a reviewer to write the rules it should have produced.
  let(:company) { create(:company) }
  let(:requester) { create(:person, company: company, location: "Lagos") }
  let(:policy) { create(:policy, company: company, category: "expense", status: "active") }
  let!(:rule) do
    create(:rule, policy: policy, status: "active", key: "expense_over_500_manager",
      source_quote: "Expenses over €500 need your manager's approval.")
  end
  let(:request) do
    create(:request, company: company, requester: requester, kind: "expense", payload: { "amount_eur" => 900 },
      decision: "require_approval", matched_rule_ids: [ "expense_over_500_manager" ], status: "approved")
  end
  let(:step_run) { create(:step_run, workflow_run: create(:workflow_run, request: request), overridden: true, override_reason: "VP signed off verbally") }

  it "creates a candidate with the matched rules' handbook quotes, the request and the reason" do
    eval_case = described_class.call(step_run: step_run)

    expect(eval_case).to have_attributes(suite: "policy_extraction", source: "override", status: "candidate", key: "override_step_run_#{step_run.id}", expected: {})
    expect(eval_case.input).to include(
      "category" => "expense", "passage" => "Expenses over €500 need your manager's approval.",
      "request" => { "payload" => { "amount_eur" => 900 }, "location" => "Lagos", "department" => requester.department.name },
      "engine_decision" => "require_approval", "final_status" => "approved"
    )
    expect(eval_case.notes).to eq("Approver override: VP signed off verbally")
  end

  it "does not store who the requester was — only what the rules saw" do
    eval_case = described_class.call(step_run: step_run)

    expect(eval_case.input.to_json).not_to include(requester.name)
  end

  it "is idempotent per step run" do
    described_class.call(step_run: step_run)
    described_class.call(step_run: step_run)

    expect(EvalCase.count).to eq(1)
  end

  it "creates nothing when the request matched no rule, since there is no handbook text to test" do
    request.update!(matched_rule_ids: [])

    expect(described_class.call(step_run: step_run)).to be_nil
    expect(EvalCase.count).to eq(0)
  end
end
