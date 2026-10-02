require "rails_helper"

RSpec.describe Agent::Tools::RunInsight do
  let(:company) { create(:company) }
  let(:asker) { create(:person, company: company) }
  let(:tool) { described_class.new(Agent::Context.new(company: company, person: asker, agent_run: nil)) }

  def call(args) = JSON.parse(tool.call(args))

  it "answers through Insights, recording it as one of the person's insight queries" do
    create(:request, company: company, requester: asker, kind: "expense")
    query = { "metric" => "request_count", "chart" => "table" }
    allow(Insights::Interpreter).to receive(:call).and_return(Insights::Interpreter::Result.new(query: query, clarification: nil))

    result = call({ "question" => "How many requests have we had?" })

    expect(result).to include("status" => "answered", "query" => query, "summary" => "Overall: 1 request.", "unit" => "count")
    expect(result["rows"]).to eq([ { "key" => nil, "label" => "Total", "value" => 1.0 } ])
    expect(InsightQuery.find(result["insight_query_id"])).to have_attributes(person: asker, question: "How many requests have we had?")
  end

  it "passes a clarifying question back for the agent to ask" do
    allow(Insights::Interpreter).to receive(:call).and_return(Insights::Interpreter::Result.new(query: nil, clarification: "Which quarter?"))

    expect(call({ "question" => "Leave last quarter?" })).to include("status" => "needs_clarification", "clarification" => "Which quarter?")
  end
end
