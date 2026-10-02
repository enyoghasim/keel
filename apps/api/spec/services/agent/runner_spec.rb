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

  it "records what the run cost, from ruby_llm's per-message pricing" do
    script(
      { tool_calls: [ { name: "check_policy", arguments: { "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } } } ], tokens: [ 1_000_000, 0 ], model: "gpt-5.1" },
      { content: "Yes.", tokens: [ 0, 100_000 ], model: "gpt-5.1" }
    )

    described_class.call(agent_run)

    expect(agent_run.reload.cost_usd).to eq(BigDecimal("2.25")) # $1.25 for 1M input + $1.00 for 100k output
  end

  it "leaves the cost unknown when the model has no pricing" do
    script({ content: "Hi!" })

    described_class.call(agent_run)

    expect(agent_run.reload.cost_usd).to be_nil
  end

  it "tells the model who it's acting for, the date, the company, and the rules of behaviour" do
    chat = script({ content: "Hi!" })

    travel_to(Date.new(2026, 10, 2)) { described_class.call(agent_run) }

    expect(chat.instructions).to include("Nubo", "Ngozi Okafor", "Account Executive", "Sales", "Tunde Bakare", "sales_lead", "2026-10-02")
    expect(chat.instructions).to include("Never state a policy outcome without calling check_policy")
    expect(chat.tools.keys).to contain_exactly("search_people", "check_policy", "create_request", "run_insight", "org_lookup", "who_approves", "list_my_requests", "search_handbook")
    expect(chat.asked).to eq("Can I expense a €1,200 flight to RubyConf?")
  end

  describe "the agent_system prompt version" do
    def version(template, **attrs) = create(:prompt_version, key: "agent_system", template: template, **attrs)

    it "uses the active version's template, filled in for this person, company and day" do
      version("You work for {{company}}, helping {{person_name}} ({{person_details}}) on {{today}}.", active: true)
      chat = script({ content: "Hi!" })

      travel_to(Date.new(2026, 10, 2)) { described_class.call(agent_run) }

      expect(chat.instructions).to eq("You work for Nubo, helping Ngozi Okafor (Account Executive, Sales; manager: Tunde Bakare; roles: sales_lead) on 2026-10-02.")
    end

    it "uses the version it is given instead of the active one, so an eval can compare prompts" do
      version("Active prompt", active: true)
      challenger = version("Challenger prompt for {{person_name}}")
      chat = script({ content: "Hi!" })

      described_class.call(agent_run, prompt_version: challenger)

      expect(chat.instructions).to eq("Challenger prompt for Ngozi Okafor")
    end
  end

  it "offers the change-proposing tools only to an hr_admin, and tells the model never to call a proposal a change" do
    agent_run.person.update!(roles: [ "hr_admin" ])
    chat = script({ content: "Hi!" })

    described_class.call(agent_run)

    expect(chat.tools.keys).to include("propose_org_change", "propose_rule_change")
    expect(chat.instructions).to include("a proposal is not a change")
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

  it "tells a person the deployment has no model key, not RubyLLM::ConfigurationError" do
    allow(RubyLLM).to receive(:chat).and_raise(RubyLLM::ConfigurationError, "Missing configuration for OpenAI: openai_api_key")

    described_class.call(agent_run)

    expect(agent_run.reload).to have_attributes(status: "failed", error_message: Llm::Failure::NO_MODEL)
  end

  it "stops a run that keeps calling tools after 8 model turns, keeping the trace so far" do
    loop_turn = { tool_calls: [ { name: "search_people", arguments: { "query" => "Tunde" } } ] }
    script(*Array.new(10, loop_turn), { content: "never reached" })

    described_class.call(agent_run)

    expect(agent_run.reload).to have_attributes(status: "failed", error_message: "Stopped after 8 model turns without a final answer.")
    expect(agent_run.agent_steps.where(kind: "llm").count).to eq(8)
  end

  describe "conversation memory" do
    def earlier(message, final_text, **attrs)
      create(:agent_run, company: company, person: asker, conversation_id: agent_run.conversation_id, message: message,
        status: "completed", final_text: final_text, **attrs)
    end

    it "replays earlier questions and answers of the same conversation, oldest first, before the new message" do
      earlier("Can I expense a flight?", "Yes, up to €500 without approval.", created_at: 2.hours.ago)
      earlier("And a hotel?", "Same limit.", created_at: 1.hour.ago)
      chat = script({ content: "Then Tunde has to approve." })

      agent_run.update!(message: "And what about €2,000?")
      described_class.call(agent_run)

      expect(chat.history).to eq([
        [ :user, "Can I expense a flight?" ], [ :assistant, "Yes, up to €500 without approval." ],
        [ :user, "And a hotel?" ], [ :assistant, "Same limit." ]
      ])
      expect(chat.asked).to eq("And what about €2,000?")
    end

    it "only keeps the last #{Agent::Runner::HISTORY_TURNS} turns, so a long conversation can't grow the prompt without bound" do
      (Agent::Runner::HISTORY_TURNS + 2).times { |i| earlier("Question #{i}", "Answer #{i}", created_at: (20 - i).minutes.ago) }
      chat = script({ content: "ok" })

      described_class.call(agent_run)

      expect(chat.history.select { _1.first == :user }.map(&:last)).to eq((2..Agent::Runner::HISTORY_TURNS + 1).map { "Question #{_1}" })
    end

    it "leaves out turns with no answer, other conversations, other people's runs and later messages" do
      earlier("Failed one", nil, status: "failed", error_message: "boom", created_at: 3.hours.ago)
      create(:agent_run, company: company, person: asker, message: "Other conversation", status: "completed", final_text: "No.", created_at: 2.hours.ago)
      create(:agent_run, company: company, conversation_id: agent_run.conversation_id, message: "Someone else", status: "completed", final_text: "No.", created_at: 90.minutes.ago)
      earlier("Asked afterwards", "Later.", created_at: 1.minute.from_now)
      chat = script({ content: "Hi" })

      described_class.call(agent_run)

      expect(chat.history).to eq([])
    end

    it "keeps each run's trace separate: the earlier turns add no steps to this run" do
      earlier("Earlier", "Answer.", created_at: 1.hour.ago)
      script({ content: "Fine." })

      described_class.call(agent_run)

      expect(agent_run.agent_steps.count).to eq(1)
    end
  end
end
