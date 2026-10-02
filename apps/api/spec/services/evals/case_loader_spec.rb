require "rails_helper"

RSpec.describe Evals::CaseLoader do
  def write_fixture(yaml)
    Tempfile.new([ "cases", ".yml" ]).tap { _1.write(yaml) && _1.flush }.path
  end

  let(:fixture) do
    write_fixture(<<~YAML)
      - key: leave_by_department
        input: { question: "Leave days by department", today: "2026-10-02" }
        expected:
          query: { metric: leave_days, group_by: department, chart: bar }
      - key: fiscal
        input: { question: "Leave last fiscal quarter", today: "2026-10-02" }
        expected: { clarification: true }
        notes: Should ask.
    YAML
  end

  it "loads every case in a fixture file into the suite as active, manual cases" do
    described_class.call(suite: "insights", path: fixture)

    cases = EvalCase.where(suite: "insights").order(:key)
    expect(cases.map(&:key)).to eq(%w[fiscal leave_by_department])
    expect(cases.last).to have_attributes(
      status: "active", source: "manual",
      input: { "question" => "Leave days by department", "today" => "2026-10-02" },
      expected: { "query" => { "metric" => "leave_days", "group_by" => "department", "chart" => "bar" } }
    )
    expect(cases.first.notes).to eq("Should ask.")
  end

  it "updates existing cases by key on reload, but keeps a reviewer's status" do
    archived = create(:eval_case, suite: "insights", key: "fiscal", status: "archived", expected: { "clarification" => false })

    described_class.call(suite: "insights", path: fixture)
    described_class.call(suite: "insights", path: fixture)

    expect(EvalCase.where(suite: "insights").count).to eq(2)
    expect(archived.reload).to have_attributes(status: "archived", expected: { "clarification" => true })
  end

  it "loads the real insights fixture, and every expected query in it is runnable by Insights::QueryBuilder" do
    path = Rails.root.join("..", "..", "fixtures", "evals", "insights.yml")
    described_class.call(suite: "insights", path: path)
    company = create(:company)

    queries = EvalCase.where(suite: "insights").filter_map { _1.expected["query"] }
    expect(queries.size).to be >= 10
    queries.each { |query| expect { Insights::QueryBuilder.call(company: company, query: query) }.not_to raise_error }
  end
end
