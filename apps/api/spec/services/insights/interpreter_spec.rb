require "rails_helper"

RSpec.describe Insights::Interpreter do
  # SPEC.md section 11, flow step 2: the LLM only turns a question into a
  # query object (or a clarifying question). It never sees a record —
  # just the vocabulary it may filter on.
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:company) { create(:company) }
  let(:today) { Date.new(2026, 10, 2) }

  def message_with(content) = instance_double(RubyLLM::Message, content: content)

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
  end

  it "turns 'Leave days by department last quarter' into a query object bound to the insight-query schema" do
    query = { "metric" => "leave_days", "group_by" => "department", "chart" => "bar",
              "time_range" => { "from" => "2026-07-01", "to" => "2026-09-30" } }
    allow(chat).to receive(:ask).and_return(message_with({ "query" => query }))

    result = described_class.call(company: company, question: "Leave days by department last quarter", today: today)

    expect(result.query).to eq(query)
    expect(result.clarification).to be_nil
    expect(chat).to have_received(:with_schema).with(Llm::SchemaRegistry.fetch("insight-query"))
  end

  it "passes back a clarifying question instead of guessing when the question is ambiguous" do
    allow(chat).to receive(:ask).and_return(message_with({ "clarification" => "Do you mean calendar Q3 or your fiscal quarter?" }))

    result = described_class.call(company: company, question: "Leave last quarter?", today: today)

    expect(result.query).to be_nil
    expect(result.clarification).to eq("Do you mean calendar Q3 or your fiscal quarter?")
  end

  it "grounds the prompt in today's date and the company's own departments and expense categories, never its people" do
    create(:department, company: company, name: "Engineering")
    ngozi = create(:person, company: company, name: "Ngozi Okafor", department: create(:department, company: company, name: "Sales"))
    create(:request, company: company, requester: ngozi, kind: "expense", payload: { "category" => "conference" })
    other = create(:company)
    create(:department, company: other, name: "Secret Projects")
    allow(chat).to receive(:ask).and_return(message_with({ "clarification" => "Which month?" }))

    described_class.call(company: company, question: "Spend by category", today: today)

    expect(chat).to have_received(:ask).with(satisfy { |prompt|
      prompt.include?("Today is 2026-10-02") &&
        prompt.include?("Departments: Engineering, Sales") &&
        prompt.include?("Expense categories: conference") &&
        prompt.include?("Spend by category") &&
        !prompt.include?("Secret Projects") &&
        !prompt.include?("Ngozi")
    })
  end

  it "reports what each ask cost, retries included, so an eval run can count it" do
    priced = ->(content, cost) { instance_double(RubyLLM::Message, content: content, cost: instance_double(RubyLLM::Cost, total: cost)) }
    allow(chat).to receive(:ask).and_return(priced.call({ "query" => { "metric" => "salaries", "chart" => "bar" } }, 0.25),
      priced.call({ "clarification" => "Which metric?" }, 0.5))
    costs = []

    described_class.call(company: company, question: "Average salary?", today: today) { costs << _1 }

    expect(costs).to eq([ 0.25, 0.5 ])
  end

  it "gives up with a validation error after a retry, rather than handing QueryBuilder an invalid object" do
    allow(chat).to receive(:ask).and_return(message_with({ "query" => { "metric" => "salaries", "chart" => "bar" } }))

    expect { described_class.call(company: company, question: "Average salary?", today: today) }
      .to raise_error(Llm::StructuredAsk::ValidationError)
    expect(chat).to have_received(:ask).twice
  end
end
