require "rails_helper"

RSpec.describe InsightJob, type: :job do
  include ActionCable::TestHelper

  # Interpreter and QueryBuilder have their own specs — this job runs one
  # after the other, records the outcome on the InsightQuery (its trace),
  # and broadcasts it. The Interpreter (the LLM) is stubbed; QueryBuilder
  # runs for real.
  let(:company) { create(:company) }
  let(:insight_query) { create(:insight_query, company: company, question: "How many requests?") }

  def interpreted(query: nil, clarification: nil)
    allow(Insights::Interpreter).to receive(:call).and_return(Insights::Interpreter::Result.new(query: query, clarification: clarification))
  end

  it "runs the interpreted query and records the query object, rows, summary and model" do
    create(:request, company: company, requester: insight_query.person, kind: "expense")
    query = { "metric" => "request_count", "chart" => "table" }
    interpreted(query: query)

    described_class.perform_now(insight_query.id)

    expect(insight_query.reload).to have_attributes(status: "answered", query: query, model: RubyLLM.config.default_model)
    expect(insight_query.result).to eq({
      "rows" => [ { "key" => nil, "label" => "Total", "value" => 1.0 } ], "unit" => "count", "summary" => "Overall: 1 request."
    })
    expect(Insights::Interpreter).to have_received(:call).with(company: company, question: "How many requests?")
  end

  it "records a clarifying question without running anything" do
    interpreted(clarification: "Calendar Q3 or fiscal?")
    allow(Insights::QueryBuilder).to receive(:call)

    described_class.perform_now(insight_query.id)

    expect(insight_query.reload).to have_attributes(status: "needs_clarification", clarification: "Calendar Q3 or fiscal?", result: nil)
    expect(Insights::QueryBuilder).not_to have_received(:call)
  end

  it "fails with QueryBuilder's friendly message, keeping the query object for inspection" do
    query = { "metric" => "leave_days", "group_by" => "approver", "chart" => "bar" }
    interpreted(query: query)

    described_class.perform_now(insight_query.id)

    expect(insight_query.reload).to have_attributes(status: "failed", query: query)
    expect(insight_query.error_message).to eq("Leave days can't be grouped by approver. Try: department, person, month.")
  end

  it "fails with a plain-language message when the LLM can't produce a valid query object" do
    allow(Insights::Interpreter).to receive(:call).and_raise(Llm::StructuredAsk::ValidationError, "metric: not in enum")

    described_class.perform_now(insight_query.id)

    expect(insight_query.reload.status).to eq("failed")
    expect(insight_query.error_message).to match(/couldn't turn that question into a query/)
  end

  it "broadcasts the finished query to whoever is watching it" do
    interpreted(clarification: "Which month?")

    expect { described_class.perform_now(insight_query.id) }
      .to have_broadcasted_to(insight_query).from_channel(InsightChannel)
      .with(hash_including("id" => insight_query.id, "status" => "needs_clarification"))
  end

  it "doesn't re-run a query that has already been answered" do
    insight_query.update!(status: "answered")
    allow(Insights::Interpreter).to receive(:call)

    described_class.perform_now(insight_query.id)

    expect(Insights::Interpreter).not_to have_received(:call)
  end
end
