require "rails_helper"

RSpec.describe Agent::Runner do
  include ActiveSupport::Testing::TimeHelpers

  # SPEC.md section 9's agent loop. The model is a FakeChat replaying a
  # script; the tools are real and run against the database.
  let(:company) { create(:company, name: "Nubo") }
  let(:sales) { create(:department, company: company, name: "Sales") }
  let(:manager) { create(:person, company: company, name: "Tunde Bakare") }
  let(:asker) { create(:person, company: company, name: "Ngozi Okafor", title: "Account Executive", department: sales, manager: manager, roles: [ "sales_lead" ]) }
  let(:agent_run) { create(:agent_run, company: company, person: asker, message: "Can I expense a €1,200 flight to RubyConf?") }

  def script(*turns)
    FakeChat.new(turns).tap { |chat| allow(RubyLLM).to receive(:chat).and_return(chat) }
  end

  before do
    policy = create(:policy, company: company, category: "expense", status: "active")
    create(:rule, policy: policy, status: "active", key: "large_expense",
      conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
  end

  it "answers an Ask with check_policy, recording every model and tool call in order with tokens and latency" do
    script(
      { tool_calls: [ { name: "check_policy", arguments: { "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } } } ], tokens: [ 900, 40 ] },
      { content: "Yes, but Tunde Bakare has to approve it first.", tokens: [ 1100, 30 ] }
    )

    described_class.call(agent_run)

    expect(agent_run.reload).to have_attributes(status: "completed", final_text: "Yes, but Tunde Bakare has to approve it first.", total_tokens: 2070)
    steps = agent_run.agent_steps
    expect(steps.map { [ _1.position, _1.kind, _1.tool_name ] }).to eq([ [ 1, "llm", nil ], [ 2, "tool", "check_policy" ], [ 3, "llm", nil ] ])
    expect(steps.first).to have_attributes(tokens: 940, output: { "content" => "", "tool_calls" => [
      { "name" => "check_policy", "arguments" => { "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } } }
    ] })
    expect(steps.second.input).to eq({ "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } })
    expect(steps.second.output).to include("decision" => "require_approval")
    expect(steps.second.output["approvers"].map { _1["name"] }).to eq([ "Tunde Bakare" ])
    expect(steps.map(&:latency_ms)).to all(be >= 0)
  end

  it "tells the model who it's acting for, the date, the company, and the rules of behaviour" do
    chat = script({ content: "Hi!" })

    travel_to(Date.new(2026, 10, 2)) { described_class.call(agent_run) }

    expect(chat.instructions).to include("Nubo", "Ngozi Okafor", "Account Executive", "Sales", "Tunde Bakare", "sales_lead", "2026-10-02")
    expect(chat.instructions).to include("Never state a policy outcome without calling check_policy")
    expect(chat.tools.keys).to contain_exactly("search_people", "check_policy", "create_request", "run_insight")
    expect(chat.asked).to eq("Can I expense a €1,200 flight to RubyConf?")
  end

  it "streams each step as it's recorded" do
    script(
      { tool_calls: [ { name: "search_people", arguments: { "query" => "Tunde" } } ] },
      { content: "Tunde is in no department." }
    )

    seen = []
    described_class.call(agent_run) { |step| seen << [ step.kind, step.tool_name ] }

    expect(seen).to eq([ [ "llm", nil ], [ "tool", "search_people" ], [ "llm", nil ] ])
  end

  it "stops a run that keeps calling tools after 8 model turns, keeping the trace so far" do
    loop_turn = { tool_calls: [ { name: "search_people", arguments: { "query" => "Tunde" } } ] }
    script(*Array.new(10, loop_turn), { content: "never reached" })

    described_class.call(agent_run)

    expect(agent_run.reload).to have_attributes(status: "failed", error_message: "Stopped after 8 model turns without a final answer.")
    expect(agent_run.agent_steps.where(kind: "llm").count).to eq(8)
  end
end
