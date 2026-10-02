require "rails_helper"

RSpec.describe Insights::QueryBuilder do
  # One example per question from SPEC.md section 11's metric table and
  # suggested questions. Each runs a hand-written query object — no LLM
  # anywhere — against real records, the same way Insights::Interpreter's
  # output is run in production.
  let(:company) { create(:company) }
  let(:engineering) { create(:department, company: company, name: "Engineering") }
  let(:sales) { create(:department, company: company, name: "Sales") }

  def person(name, department, **attrs) = create(:person, company: company, department: department, name: name, **attrs)

  def submit(requester, kind:, payload: {}, status: "approved", decision: "require_approval", at: Time.zone.parse("2026-08-10 09:00"), matched: [])
    create(:request, company: company, requester: requester, kind: kind, payload: payload,
      status: status, decision: decision, matched_rule_ids: matched, created_at: at)
  end

  # An approval step run as Workflows::Runtime creates it: the approver is
  # baked into a person:<id> reference, resolved_person_id is only filled
  # in once the step becomes active.
  def approval_step(request, approver, status: "done", acted_at: nil, resolved: true, overridden: false)
    workflow_run = request.workflow_run || create(:workflow_run, request: request, workflow: nil, status: "in_progress")
    create(:step_run, workflow_run: workflow_run, step_key: "approval", reference: "person:#{approver.id}",
      resolved_person_id: resolved ? approver.id : nil, status: status, acted_at: acted_at, overridden: overridden)
  end

  def run(query) = described_class.call(company: company, query: query)
  def rows(result) = result.rows.map { [ _1.label, _1.value ] }

  it "answers 'Leave days by department last quarter' from approved leave only, inside the time range" do
    ngozi = person("Ngozi", sales)
    tunde = person("Tunde", engineering)
    submit(ngozi, kind: "leave", payload: { "days" => 5 }, at: Time.zone.parse("2026-07-02 10:00"))
    submit(ngozi, kind: "leave", payload: { "days" => 3 }, at: Time.zone.parse("2026-09-30 23:30"))
    submit(tunde, kind: "leave", payload: { "days" => 2 })
    submit(tunde, kind: "leave", payload: { "days" => 10 }, status: "rejected")
    submit(tunde, kind: "leave", payload: { "days" => 4 }, status: "pending")
    submit(tunde, kind: "leave", payload: { "days" => 9 }, at: Time.zone.parse("2026-06-30 12:00"))
    submit(tunde, kind: "expense", payload: { "amount_eur" => 100, "days" => 99 })

    result = run({ "metric" => "leave_days", "group_by" => "department", "chart" => "bar",
                   "time_range" => { "from" => "2026-07-01", "to" => "2026-09-30" } })

    expect(rows(result)).to eq([ [ "Sales", 8.0 ], [ "Engineering", 2.0 ] ])
    expect(result.unit).to eq("days")
  end

  it "answers 'Expense spend by category' from approved expenses only" do
    ngozi = person("Ngozi", sales)
    submit(ngozi, kind: "expense", payload: { "amount_eur" => 1200, "category" => "conference" })
    submit(ngozi, kind: "expense", payload: { "amount_eur" => 300.5, "category" => "conference" })
    submit(ngozi, kind: "expense", payload: { "amount_eur" => 80, "category" => "meals" })
    submit(ngozi, kind: "expense", payload: { "amount_eur" => 5000, "category" => "meals" }, status: "rejected")

    result = run({ "metric" => "expense_total", "group_by" => "category", "chart" => "pie" })

    expect(rows(result)).to eq([ [ "conference", 1500.5 ], [ "meals", 80.0 ] ])
    expect(result.unit).to eq("eur")
  end

  it "counts requests by month in chronological order, whatever the sort, so a line chart reads left to right" do
    ngozi = person("Ngozi", sales)
    submit(ngozi, kind: "expense", at: Time.zone.parse("2026-09-03"))
    submit(ngozi, kind: "expense", at: Time.zone.parse("2026-07-15"))
    submit(ngozi, kind: "leave", at: Time.zone.parse("2026-07-20"), status: "pending")

    result = run({ "metric" => "request_count", "group_by" => "month", "sort" => "desc", "chart" => "line" })

    expect(result.rows.map { [ _1.key, _1.label, _1.value ] }).to eq([ [ "2026-07", "Jul 2026", 2.0 ], [ "2026-09", "Sep 2026", 1.0 ] ])
  end

  it "returns a single total row when no group_by is given" do
    ngozi = person("Ngozi", sales)
    2.times { submit(ngozi, kind: "expense") }

    result = run({ "metric" => "request_count", "chart" => "table" })

    expect(rows(result)).to eq([ [ "Total", 2.0 ] ])
  end

  it "applies whitelisted filters on kind, department and category" do
    ngozi = person("Ngozi", sales)
    tunde = person("Tunde", engineering)
    submit(ngozi, kind: "expense", payload: { "category" => "travel" })
    submit(ngozi, kind: "expense", payload: { "category" => "meals" })
    submit(ngozi, kind: "leave")
    submit(tunde, kind: "expense", payload: { "category" => "travel" })

    result = run({ "metric" => "request_count", "group_by" => "kind", "chart" => "bar", "filters" => [
      { "field" => "requester.department", "op" => "eq", "value" => "Sales" },
      { "field" => "request.kind", "op" => "in", "value" => [ "expense", "equipment" ] },
      { "field" => "payload.category", "op" => "neq", "value" => "meals" }
    ] })

    expect(rows(result)).to eq([ [ "expense", 1.0 ] ])
  end

  it "answers 'Who is overloaded with approvals?' from pending and completed approval steps, including ones not yet active" do
    ada = person("Ada", engineering)
    tunde = person("Tunde", engineering)
    ngozi = person("Ngozi", sales)
    3.times { approval_step(submit(ngozi, kind: "expense", status: "pending"), ada, status: "pending") }
    approval_step(submit(ngozi, kind: "expense"), ada, status: "done")
    approval_step(submit(ngozi, kind: "expense", status: "pending"), tunde, status: "pending", resolved: false)
    approval_step(submit(ngozi, kind: "expense", status: "rejected"), tunde, status: "cancelled")

    notify_run = create(:workflow_run, request: submit(ngozi, kind: "expense"), workflow: nil)
    create(:step_run, workflow_run: notify_run, step_key: "finance", reference: "role:finance_lead", resolved_person_id: tunde.id, status: "done")

    result = run({ "metric" => "approval_load", "group_by" => "approver", "chart" => "bar" })

    expect(rows(result)).to eq([ [ "Ada", 4.0 ], [ "Tunde", 1.0 ] ])
    expect(result.rows.map(&:key)).to eq([ ada.id, tunde.id ])
  end

  it "groups approval load by the approver's department, not the requester's" do
    ada = person("Ada", engineering)
    ngozi = person("Ngozi", sales)
    2.times { approval_step(submit(ngozi, kind: "expense", status: "pending"), ada, status: "pending") }

    result = run({ "metric" => "approval_load", "group_by" => "department", "chart" => "bar" })

    expect(rows(result)).to eq([ [ "Engineering", 2.0 ] ])
  end

  it "answers 'Median time to approve' in hours from submission to the last step acted on" do
    ada = person("Ada", engineering)
    ngozi = person("Ngozi", sales)
    submitted = Time.zone.parse("2026-08-10 09:00")
    [ 2, 4, 30 ].each do |hours|
      approval_step(submit(ngozi, kind: "expense", at: submitted), ada, acted_at: submitted + hours.hours)
    end
    approval_step(submit(ngozi, kind: "leave", at: submitted), ada, acted_at: submitted + 10.hours)
    approval_step(submit(ngozi, kind: "leave", at: submitted, status: "pending"), ada, status: "pending")

    result = run({ "metric" => "time_to_decision", "group_by" => "kind", "chart" => "bar" })

    expect(rows(result)).to eq([ [ "leave", 10.0 ], [ "expense", 4.0 ] ])
    expect(result.unit).to eq("hours")
  end

  it "answers 'How often do managers override the expense policy?' per matched rule, over decided requests" do
    ada = person("Ada", engineering)
    ngozi = person("Ngozi", sales)
    approval_step(submit(ngozi, kind: "expense", matched: [ "expense_small" ]), ada, overridden: true)
    3.times { approval_step(submit(ngozi, kind: "expense", matched: [ "expense_small" ]), ada) }
    approval_step(submit(ngozi, kind: "expense", matched: [ "expense_large" ]), ada, overridden: true)
    approval_step(submit(ngozi, kind: "expense", matched: [ "expense_large" ], status: "pending"), ada, status: "pending")

    result = run({ "metric" => "override_rate", "group_by" => "rule", "chart" => "bar" })

    expect(rows(result)).to eq([ [ "expense_large", 100.0 ], [ "expense_small", 25.0 ] ])
    expect(result.unit).to eq("percent")
  end

  it "answers auto-approval rate per policy, matching each request to its kind's active policy" do
    create(:policy, company: company, title: "Expense Policy", category: "expense", status: "active")
    create(:policy, company: company, title: "Old Expense Policy", category: "expense", status: "superseded")
    create(:policy, company: company, title: "Leave Policy", category: "leave", status: "active")
    ngozi = person("Ngozi", sales)
    submit(ngozi, kind: "expense", decision: "auto_approve")
    submit(ngozi, kind: "expense", decision: "require_approval")
    submit(ngozi, kind: "leave", decision: "auto_approve")
    submit(ngozi, kind: "equipment", decision: "require_approval")

    result = run({ "metric" => "auto_approval_rate", "group_by" => "policy", "chart" => "bar" })

    expect(rows(result)).to eq([ [ "Leave Policy", 100.0 ], [ "Expense Policy", 50.0 ], [ "No policy", 0.0 ] ])
  end

  it "never counts another company's records" do
    ngozi = person("Ngozi", sales)
    submit(ngozi, kind: "expense")
    other = create(:company)
    create(:request, company: other, requester: create(:person, company: other), kind: "expense", status: "approved")

    result = run({ "metric" => "request_count", "chart" => "table" })

    expect(rows(result)).to eq([ [ "Total", 1.0 ] ])
  end

  it "sorts ascending and applies the limit when asked" do
    %w[A B C].each_with_index do |name, i|
      requester = person(name, create(:department, company: company, name: "Dept #{name}"))
      (i + 1).times { submit(requester, kind: "expense") }
    end

    result = run({ "metric" => "request_count", "group_by" => "department", "sort" => "asc", "limit" => 2, "chart" => "bar" })

    expect(rows(result)).to eq([ [ "Dept A", 1.0 ], [ "Dept B", 2.0 ] ])
  end

  it "writes a one-line summary from the computed rows, with no LLM" do
    submit(person("Ngozi", sales), kind: "leave", payload: { "days" => 5 })
    submit(person("Tunde", engineering), kind: "leave", payload: { "days" => 2 })

    result = run({ "metric" => "leave_days", "group_by" => "department", "chart" => "bar" })

    expect(result.summary).to eq("Sales is highest with 5 days, out of 2 departments.")
  end

  it "starts the summary with a capital even when the top group is a lowercase category" do
    submit(person("Ngozi", sales), kind: "expense", payload: { "amount_eur" => 90, "category" => "travel" })

    result = run({ "metric" => "expense_total", "group_by" => "category", "chart" => "pie" })

    expect(result.summary).to eq("Travel is highest with €90, out of 1 category.")
  end

  it "says so when nothing matches" do
    result = run({ "metric" => "leave_days", "group_by" => "department", "chart" => "bar" })

    expect(result.rows).to eq([])
    expect(result.summary).to eq("No matching data for this question.")
  end

  it "rejects a group_by the metric has no scope for, listing the ones it does" do
    expect { run({ "metric" => "leave_days", "group_by" => "approver", "chart" => "bar" }) }
      .to raise_error(described_class::InvalidQuery, "Leave days can't be grouped by approver. Try: department, person, month.")
  end

  it "rejects anything outside the schema's whitelist, listing the available metrics" do
    expect { run({ "metric" => "salaries", "chart" => "bar" }) }
      .to raise_error(described_class::InvalidQuery, /Available metrics: request_count, leave_days, expense_total/)
  end

  it "rejects a filter field that isn't whitelisted rather than passing it to SQL" do
    query = { "metric" => "request_count", "chart" => "bar",
              "filters" => [ { "field" => "people.email", "op" => "eq", "value" => "x" } ] }

    expect { run(query) }.to raise_error(described_class::InvalidQuery)
  end
end
