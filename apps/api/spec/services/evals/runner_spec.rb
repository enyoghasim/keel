require "rails_helper"

RSpec.describe Evals::Runner do
  # Runs every active case in the insights suite through the real
  # Insights::Interpreter call path (the LLM itself is stubbed per case)
  # and scores each with Evals::InsightsScorer.
  let(:company) { create(:company) }
  let(:eval_run) { create(:eval_run, company: company, suite: "insights") }
  let(:leave_query) do
    { "metric" => "leave_days", "group_by" => "department", "chart" => "bar",
      "time_range" => { "from" => "2026-07-01", "to" => "2026-09-30" } }
  end

  def interpreter_returns(question, query: nil, clarification: nil)
    allow(Insights::Interpreter).to receive(:call)
      .with(company: company, question: question, today: Date.new(2026, 10, 2))
      .and_return(Insights::Interpreter::Result.new(query: query, clarification: clarification))
  end

  def add_case(key, question, expected)
    create(:eval_case, suite: "insights", key: key, input: { "question" => question, "today" => "2026-10-02" }, expected: expected)
  end

  it "scores every active case and records accuracy, counts and the model on the run" do
    add_case("leave", "Leave by department last quarter", { "query" => leave_query })
    add_case("fiscal", "Leave last fiscal quarter", { "clarification" => true })
    create(:eval_case, suite: "insights", status: "candidate")
    create(:eval_case, suite: "agent")
    interpreter_returns("Leave by department last quarter", query: leave_query.merge("chart" => "pie"))
    interpreter_returns("Leave last fiscal quarter", query: leave_query)

    described_class.call(eval_run)

    expect(eval_run.reload).to have_attributes(status: "completed", cases_count: 2, passed_count: 1, model: RubyLLM.config.default_model)
    expect(eval_run.accuracy).to eq(0.5)
    expect(eval_run.started_at).to be_present
    expect(eval_run.finished_at).to be_present

    fiscal = eval_run.eval_results.joins(:eval_case).find_by(eval_cases: { key: "fiscal" })
    expect(fiscal).to have_attributes(passed: false, actual: { "query" => leave_query })
    expect(fiscal.diff).to eq([ { "field" => "clarification", "expected" => true, "actual" => leave_query } ])
    expect(fiscal.latency_ms).to be >= 0
  end

  it "records a case whose output failed schema validation as a failure with the reason, and keeps going" do
    add_case("a_broken", "Average salary?", { "query" => leave_query })
    add_case("b_leave", "Leave by department last quarter", { "query" => leave_query })
    allow(Insights::Interpreter).to receive(:call).with(hash_including(question: "Average salary?"))
      .and_raise(Llm::StructuredAsk::ValidationError, "metric: not in enum")
    interpreter_returns("Leave by department last quarter", query: leave_query)

    described_class.call(eval_run)

    broken = eval_run.eval_results.joins(:eval_case).find_by(eval_cases: { key: "a_broken" })
    expect(broken).to have_attributes(passed: false, actual: nil, error_message: "Output failed schema validation: metric: not in enum")
    expect(eval_run.reload).to have_attributes(status: "completed", passed_count: 1, cases_count: 2)
  end

  it "reports progress after each case, so the Trust page can fill in live" do
    add_case("leave", "Leave by department last quarter", { "query" => leave_query })
    interpreter_returns("Leave by department last quarter", query: leave_query)

    progress = []
    described_class.call(eval_run) { |result, done, total| progress << [ result.passed, done, total ] }

    expect(progress).to eq([ [ true, 1, 1 ] ])
  end

  it "refuses a suite it can't run rather than recording a meaningless score" do
    bogus = create(:eval_run, company: company, suite: "insights")
    bogus.update_columns(suite: "nonsense")

    expect { described_class.call(bogus) }.to raise_error(ArgumentError, /nonsense suite isn't runnable/)
  end

  describe "the policy_extraction suite" do
    # Compiles each case's passage with the run's prompt version and scores
    # it by behaviour (Evals::PolicyExtractionScorer); with stability samples
    # it compiles the passage several times and measures their agreement.
    let(:eval_run) { create(:eval_run, company: company, suite: "policy_extraction") }
    let(:passage) { "Engineers attending conferences are automatically approved up to €1,000." }
    let(:conditions) do
      ->(op) { { "all" => [
        { "field" => "requester.department", "op" => "eq", "value" => "Engineering" },
        { "field" => "payload.amount_eur", "op" => op, "value" => 1000 }
      ] } }
    end

    def compiled(op)
      [ { "key" => "conf", "priority" => 10, "conditions" => conditions.call(op), "actions" => { "decision" => "auto_approve" },
          "source_quote" => passage, "ambiguities" => [] } ]
    end

    before do
      create(:eval_case, suite: "policy_extraction", key: "conf", input: { "category" => "expense", "passage" => passage },
        expected: { "rules" => [ { "key" => "x", "priority" => 10, "conditions" => conditions.call("lte"), "actions" => { "decision" => "auto_approve" } } ] })
    end

    it "scores the compiled rules by behaviour and records what the model produced" do
      allow(Assemble::PolicyExtractor).to receive(:compile).and_return(compiled("lt"))

      described_class.call(eval_run)

      result = eval_run.eval_results.sole
      expect(result.passed).to be(false)
      expect(result.score.to_f).to be_within(0.001).of(2 / 3.0)
      expect(result.actual["rules"].first["key"]).to eq("conf")
      expect(result.diff.first).to include("field" => "behaviour", "expected" => "auto_approve")
      expect(eval_run.reload).to have_attributes(status: "completed", passed_count: 0, cases_count: 1)
      expect(eval_run.accuracy).to eq(0)
    end

    it "compiles with the run's prompt version, recording which one was used" do
      version = create(:prompt_version, version: 1)
      eval_run.update!(prompt_version: version)
      allow(Assemble::PolicyExtractor).to receive(:compile).and_return(compiled("lte"))

      described_class.call(eval_run)

      expect(Assemble::PolicyExtractor).to have_received(:compile).with(
        category: "expense", chunks: [ an_object_having_attributes(text: passage) ], prompt_version: version
      )
    end

    it "falls back to the active prompt version and records it on the run" do
      active = create(:prompt_version, version: 2, active: true)
      allow(Assemble::PolicyExtractor).to receive(:compile).and_return(compiled("lte"))

      described_class.call(eval_run)

      expect(eval_run.reload.prompt_version).to eq(active)
    end

    it "measures compile stability across samples and averages it onto the run" do
      eval_run.update!(stability_samples: 3)
      allow(Assemble::PolicyExtractor).to receive(:compile).and_return(compiled("lte"), compiled("lte"), compiled("lt"))

      described_class.call(eval_run)

      expect(Assemble::PolicyExtractor).to have_received(:compile).exactly(3).times
      result = eval_run.eval_results.sole
      expect(result.passed).to be(true) # the first sample is the scored output
      expect(result.metrics["stability"]).to be_within(0.001).of((1 + 2 / 3.0 + 2 / 3.0) / 3)
      expect(eval_run.reload.stability.to_f).to be_within(0.001).of(result.metrics["stability"])
    end

    it "records a compile that fails schema validation as a failure and keeps going" do
      allow(Assemble::PolicyExtractor).to receive(:compile).and_raise(Llm::StructuredAsk::ValidationError, "rules: required")

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole).to have_attributes(passed: false, error_message: "Output failed schema validation: rules: required")
    end
  end
end
