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

  it "refuses a suite it can't run yet rather than recording a meaningless score" do
    agent_run = create(:eval_run, company: company, suite: "agent")

    expect { described_class.call(agent_run) }.to raise_error(ArgumentError, /agent suite isn't runnable yet/)
  end
end
