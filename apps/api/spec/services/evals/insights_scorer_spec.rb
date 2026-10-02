require "rails_helper"

RSpec.describe Evals::InsightsScorer do
  # SPEC.md section 12: the insights suite is scored field by field on
  # metric, group_by, filters and time range. Presentation fields (chart,
  # sort, limit) don't change what was asked, so they aren't scored.
  def score(expected, actual) = described_class.call(expected: expected, actual: actual)

  let(:leave_by_department) do
    { "query" => { "metric" => "leave_days", "group_by" => "department", "chart" => "bar",
                   "time_range" => { "from" => "2026-07-01", "to" => "2026-09-30" } } }
  end

  it "passes an exact match, with every scored field checked" do
    result = score(leave_by_department, leave_by_department)

    expect(result.passed).to be(true)
    expect(result.checks.map(&:field)).to eq(%w[metric group_by filters time_range])
    expect(result.diff).to eq([])
  end

  it "ignores chart, sort and limit — they change how the answer looks, not what was asked" do
    actual = { "query" => leave_by_department["query"].merge("chart" => "pie", "sort" => "asc", "limit" => 5) }

    expect(score(leave_by_department, actual).passed).to be(true)
  end

  it "fails on the wrong time range and says exactly which field differed" do
    actual = { "query" => leave_by_department["query"].merge("time_range" => { "from" => "2026-04-01", "to" => "2026-06-30" }) }

    result = score(leave_by_department, actual)

    expect(result.passed).to be(false)
    expect(result.diff).to eq([
      { "field" => "time_range",
        "expected" => { "from" => "2026-07-01", "to" => "2026-09-30" },
        "actual" => { "from" => "2026-04-01", "to" => "2026-06-30" } }
    ])
  end

  it "treats filters as a set, and an eq on one value the same as an in on that one value" do
    expected = { "query" => { "metric" => "request_count", "chart" => "bar", "filters" => [
      { "field" => "request.kind", "op" => "eq", "value" => "expense" },
      { "field" => "payload.category", "op" => "in", "value" => %w[travel meals] }
    ] } }
    actual = { "query" => { "metric" => "request_count", "chart" => "bar", "filters" => [
      { "field" => "payload.category", "op" => "in", "value" => %w[meals travel] },
      { "field" => "request.kind", "op" => "in", "value" => [ "expense" ] }
    ] } }

    expect(score(expected, actual).passed).to be(true)
  end

  it "fails a missing filter" do
    expected = { "query" => { "metric" => "override_rate", "group_by" => "rule", "chart" => "bar",
                              "filters" => [ { "field" => "request.kind", "op" => "eq", "value" => "expense" } ] } }
    actual = { "query" => { "metric" => "override_rate", "group_by" => "rule", "chart" => "bar" } }

    result = score(expected, actual)

    expect(result.passed).to be(false)
    expect(result.diff.map { _1["field"] }).to eq([ "filters" ])
  end

  it "passes any clarifying question when the case expects the model to ask rather than guess" do
    expect(score({ "clarification" => true }, { "clarification" => "Calendar or fiscal Q3?" }).passed).to be(true)
  end

  it "fails a guess where a clarifying question was expected, and vice versa" do
    guessed = score({ "clarification" => true }, leave_by_department)
    asked = score(leave_by_department, { "clarification" => "Which quarter?" })

    expect(guessed.passed).to be(false)
    expect(guessed.diff).to eq([ { "field" => "clarification", "expected" => true, "actual" => leave_by_department["query"] } ])
    expect(asked.passed).to be(false)
    expect(asked.diff).to eq([ { "field" => "query", "expected" => leave_by_department["query"], "actual" => "Which quarter?" } ])
  end
end
