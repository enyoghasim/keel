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

  it "adds what each interpretation cost onto the case and the run" do
    add_case("leave", "Leave by department last quarter", { "query" => leave_query })
    allow(Insights::Interpreter).to receive(:call) do |**, &on_cost|
      on_cost.call(0.25)
      Insights::Interpreter::Result.new(query: leave_query, clarification: nil)
    end

    described_class.call(eval_run)

    expect(eval_run.eval_results.sole.metrics["cost_usd"]).to eq(0.25)
    expect(eval_run.reload.cost_usd).to eq(BigDecimal("0.25"))
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

    it "adds what each compile cost onto the case and the run" do
      allow(Assemble::PolicyExtractor).to receive(:compile) { |**, &on_cost| on_cost.call(0.5).then { compiled("lte") } }
      eval_run.update!(stability_samples: 3)

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole.metrics["cost_usd"]).to eq(1.5)
      expect(eval_run.reload.cost_usd).to eq(BigDecimal("1.5"))
    end

    it "records a compile that fails schema validation as a failure and keeps going" do
      allow(Assemble::PolicyExtractor).to receive(:compile).and_raise(Llm::StructuredAsk::ValidationError, "rules: required")

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole).to have_attributes(passed: false, error_message: "Output failed schema validation: rules: required")
    end
  end

  describe "the agent suite" do
    # Replays each case's message through the real Agent::Runner as the
    # named person, scores tool selection and outcome deterministically, and
    # has Evals::Judge grade the wording. Everything the agent writes is
    # rolled back: an eval must never file a real request.
    let(:eval_run) { create(:eval_run, company: company, suite: "agent") }
    let!(:manager) { create(:person, company: company, name: "Tunde Bakare") }
    let!(:asker) { create(:person, company: company, name: "Ngozi Okafor", email: "ngozi@nubo.test", manager: manager) }
    let(:judgement) { Evals::Judge::Result.new({ "correctness" => 5, "citation" => 4, "clarity" => 5, "no_false_claims" => 5 }, 4.75, "Fine.") }
    let(:check) { { tool_calls: [ { name: "check_policy", arguments: { "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } } } ] } }

    before do
      policy = create(:policy, company: company, category: "expense", status: "active")
      create(:rule, policy: policy, status: "active", key: "large_expense",
        conditions: { "field" => "payload.amount_eur", "op" => "gt", "value" => 500 },
        actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
      create(:workflow, company: company, status: "active", trigger: { "request_kind" => "expense" },
        steps: [ { "key" => "approval", "type" => "approval" } ])
      allow(Evals::Judge).to receive(:call).and_return(judgement)
    end

    def script(*turns) = FakeChat.new(turns).tap { |chat| allow(RubyLLM).to receive(:chat).and_return(chat) }

    def add_agent_case(key: "ask_flight", input: {}, expected: {})
      create(:eval_case, suite: "agent", key: key,
        input: { "message" => "Can I expense a €1,200 flight?", "person_email" => "ngozi@nubo.test" }.merge(input),
        expected: { "tools" => [ "check_policy" ], "forbidden_tools" => [ "create_request" ],
                    "outputs" => { "check_policy" => { "decision" => "require_approval" } } }.merge(expected))
    end

    it "runs the agent as the named person and scores tool selection, outcome and the judge's grades" do
      add_agent_case
      script(check, { content: "Yes, Tunde Bakare has to approve it." })

      described_class.call(eval_run)

      result = eval_run.eval_results.sole
      expect(result).to have_attributes(passed: true, diff: [])
      expect(result.actual["final_text"]).to eq("Yes, Tunde Bakare has to approve it.")
      expect(result.actual["tool_calls"].first).to include("name" => "check_policy")
      expect(result.metrics["judge"]).to eq({ "correctness" => 5, "citation" => 4, "clarity" => 5, "no_false_claims" => 5, "mean" => 4.75 })
      expect(Evals::Judge).to have_received(:call).with(message: "Can I expense a €1,200 flight?", tool_calls: [ a_hash_including("name" => "check_policy") ], answer: "Yes, Tunde Bakare has to approve it.")
      expect(eval_run.reload).to have_attributes(passed_count: 1, status: "completed")
      expect(eval_run.judge_score.to_f).to eq(4.75)
    end

    it "adds up what the agent runs cost onto the eval run" do
      add_agent_case
      script(check.merge(tokens: [ 1_000_000, 0 ], model: "gpt-5.1"), { content: "Yes.", tokens: [ 0, 100_000 ], model: "gpt-5.1" })

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole.metrics["cost_usd"]).to eq(2.25)
      expect(eval_run.reload.cost_usd).to eq(BigDecimal("2.25"))
    end

    it "runs the agent with the run's prompt version, or else the active one, recording which was used" do
      add_agent_case
      version = create(:prompt_version, key: "agent_system", version: 1, template: "Challenger for {{person_name}}")
      active = create(:prompt_version, key: "agent_system", version: 2, template: "Active for {{person_name}}", active: true)
      chat = script(check, { content: "Yes." })
      eval_run.update!(prompt_version: version)

      described_class.call(eval_run)

      expect(chat.instructions).to eq("Challenger for Ngozi Okafor")

      other_run = create(:eval_run, company: company, suite: "agent")
      chat = script(check, { content: "Yes." })
      described_class.call(other_run)

      expect(chat.instructions).to eq("Active for Ngozi Okafor")
      expect(other_run.reload.prompt_version).to eq(active)
    end

    it "counts the judge's cost along with the agent's" do
      add_agent_case
      script(check.merge(tokens: [ 1_000_000, 0 ], model: "gpt-5.1"), { content: "Yes.", tokens: [ 0, 100_000 ], model: "gpt-5.1" })
      allow(Evals::Judge).to receive(:call).and_return(Evals::Judge::Result.new(judgement.scores, judgement.mean, "Fine.", 0.5))

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole.metrics["cost_usd"]).to eq(2.75)
      expect(eval_run.reload.cost_usd).to eq(BigDecimal("2.75"))
    end

    it "fails a case where the agent used a forbidden tool, and leaves no request or run behind" do
      add_agent_case
      script(
        { tool_calls: [ { name: "create_request", arguments: { "request_kind" => "expense", "payload" => { "amount_eur" => 1200 } } } ] },
        { content: "Done, I filed it." }
      )

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole.passed).to be(false)
      expect(eval_run.eval_results.sole.diff).to include(a_hash_including("field" => "forbidden_tools"))
      expect(Request.count).to eq(0)
      expect(AgentRun.count).to eq(0)
    end

    it "replays earlier turns of the conversation before the message" do
      add_agent_case(input: { "history" => [ { "message" => "Hi", "final_text" => "Hello Ngozi!" } ] })
      chat = script(check, { content: "Yes." })

      described_class.call(eval_run)

      expect(chat.history).to eq([ [ :user, "Hi" ], [ :assistant, "Hello Ngozi!" ] ])
    end

    it "measures how closely the judge agrees with hand-labelled cases" do
      label = { "correctness" => 5, "citation" => 2, "clarity" => 5, "no_false_claims" => 5 }
      add_agent_case(expected: { "judge_label" => label })
      script(check, { content: "Yes." })

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole.metrics["judge_agreement"]).to eq(0.75)
      expect(eval_run.reload.judge_agreement.to_f).to eq(0.75)
    end

    it "records a case whose acting person doesn't exist as a failure with the reason" do
      add_agent_case(input: { "person_email" => "nobody@nubo.test" })

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole).to have_attributes(passed: false, error_message: "Nobody with the email nobody@nubo.test in this company")
    end

    it "records a run that failed (e.g. the model never answered) as a failure" do
      add_agent_case
      loop_turn = { tool_calls: [ { name: "search_people", arguments: { "query" => "x" } } ] }
      script(*Array.new(10, loop_turn), { content: "never" })

      described_class.call(eval_run)

      expect(eval_run.eval_results.sole).to have_attributes(passed: false)
      expect(eval_run.eval_results.sole.error_message).to match(/Stopped after 8 model turns/)
      expect(Evals::Judge).not_to have_received(:call)
    end
  end
end
