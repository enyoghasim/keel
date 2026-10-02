module Evals
  # Runs one EvalRun (SPEC.md section 12): every active case in the suite
  # goes through the same AI service production uses, and is scored by a
  # deterministic scorer. SUITES is the extension point: a suite is a
  # lambda that runs one case and returns its saved EvalResult.
  class Runner
    SUITES = {
      "insights" => ->(eval_run, eval_case) { run_insights_case(eval_run, eval_case) },
      "policy_extraction" => ->(eval_run, eval_case) { run_policy_extraction_case(eval_run, eval_case) },
      "agent" => ->(eval_run, eval_case) { run_agent_case(eval_run, eval_case) }
    }.freeze

    # Which prompt_versions key each suite's AI service reads.
    PROMPT_KEYS = { "policy_extraction" => Assemble::PolicyExtractor::PROMPT_KEY }.freeze

    def self.call(eval_run, &on_progress)
      run_case = SUITES.fetch(eval_run.suite) { raise ArgumentError, "the #{eval_run.suite} suite isn't runnable" }
      cases = EvalCase.active.where(suite: eval_run.suite).order(:key).to_a
      eval_run.update!(status: "running", started_at: Time.current, model: RubyLLM.config.default_model, cases_count: cases.size)
      eval_run.update!(prompt_version: PromptVersion.active_for(PROMPT_KEYS[eval_run.suite])) if eval_run.prompt_version.nil? && PROMPT_KEYS[eval_run.suite]

      cases.each_with_index do |eval_case, i|
        result = run_case.call(eval_run, eval_case)
        on_progress&.call(result, i + 1, cases.size)
      end

      passed = eval_run.eval_results.where(passed: true).count
      eval_run.update!(status: "completed", finished_at: Time.current, passed_count: passed,
        accuracy: cases.empty? ? nil : passed.fdiv(cases.size), stability: average_metric(eval_run, "stability"),
        judge_score: average_metric(eval_run, "judge", "mean"), judge_agreement: average_metric(eval_run, "judge_agreement"))
      eval_run
    end

    def self.average_metric(eval_run, *path)
      values = eval_run.eval_results.map { _1.metrics.dig(*path) }.compact
      values.empty? ? nil : values.sum / values.size
    end
    private_class_method :average_metric

    # Compiles the case's passage with the run's prompt version — several
    # times when the run measures stability, scoring the first output — and
    # scores it by behaviour (Evals::PolicyExtractionScorer).
    def self.run_policy_extraction_case(eval_run, eval_case)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      passage = eval_case.input.fetch("passage")
      chunk = Struct.new(:page, :text).new(1, passage)
      samples = Array.new([ eval_run.stability_samples, 1 ].max) do
        Assemble::PolicyExtractor.compile(category: eval_case.input.fetch("category"), chunks: [ chunk ], prompt_version: eval_run.prompt_version)
      end

      score = PolicyExtractionScorer.call(expected: eval_case.expected, actual_rules: samples.first, passage: passage)
      metrics = score.metrics
      metrics = metrics.merge("stability" => Behaviour.agreement(samples.map { |rules| rules.map { PolicyExtractionScorer.rule_definition(_1) } })) if samples.size > 1
      actual = { "rules" => samples.first, "ambiguities" => samples.first.flat_map { |rule| (rule["ambiguities"] || []).pluck("phrase") } }

      EvalResult.create!(eval_run: eval_run, eval_case: eval_case, passed: score.passed, score: score.score, metrics: metrics,
        actual: actual, diff: score.diff, latency_ms: elapsed_ms(started))
    rescue Llm::StructuredAsk::ValidationError => e
      EvalResult.create!(eval_run: eval_run, eval_case: eval_case, passed: false,
        error_message: "Output failed schema validation: #{e.message}", latency_ms: elapsed_ms(started))
    end
    private_class_method :run_policy_extraction_case

    def self.run_insights_case(eval_run, eval_case)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      interpretation = Insights::Interpreter.call(
        company: eval_run.company, question: eval_case.input.fetch("question"), today: Date.iso8601(eval_case.input.fetch("today"))
      )
      actual = { "query" => interpretation.query, "clarification" => interpretation.clarification }.compact
      score = InsightsScorer.call(expected: eval_case.expected, actual: actual)

      EvalResult.create!(eval_run: eval_run, eval_case: eval_case, passed: score.passed, actual: actual, diff: score.diff,
        latency_ms: elapsed_ms(started))
    rescue Llm::StructuredAsk::ValidationError => e
      EvalResult.create!(eval_run: eval_run, eval_case: eval_case, passed: false,
        error_message: "Output failed schema validation: #{e.message}", latency_ms: elapsed_ms(started))
    end
    private_class_method :run_insights_case

    # Runs the case's message through the real Agent::Runner as the named
    # person, reads the recorded trace, then rolls everything back so the
    # agent's writes (a filed request, a proposal) never reach real data.
    # Scores tool selection and outcome deterministically (AgentScorer) and
    # has Evals::Judge grade the wording.
    def self.run_agent_case(eval_run, eval_case)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      observed = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        observed = observe_agent(eval_run.company, eval_case)
        raise ActiveRecord::Rollback
      end

      if observed[:status] != "completed"
        return EvalResult.create!(eval_run: eval_run, eval_case: eval_case, passed: false, actual: observed.slice(:tool_calls, :final_text).stringify_keys,
          error_message: observed[:error], latency_ms: elapsed_ms(started))
      end

      score = AgentScorer.call(expected: eval_case.expected, tool_calls: observed[:tool_calls])
      judged = Judge.call(message: eval_case.input.fetch("message"), tool_calls: observed[:tool_calls], answer: observed[:final_text])
      metrics = { "judge" => judged.scores.merge("mean" => judged.mean), "judge_rationale" => judged.rationale }
      if (label = eval_case.expected["judge_label"])
        metrics["judge_agreement"] = Judge.agreement(judged.scores, label)
      end

      EvalResult.create!(eval_run: eval_run, eval_case: eval_case, passed: score.passed, score: score.passed ? 1 : 0, metrics: metrics,
        actual: { "tool_calls" => observed[:tool_calls], "final_text" => observed[:final_text] }, diff: score.diff, latency_ms: elapsed_ms(started))
    rescue ActiveRecord::RecordNotFound, Llm::StructuredAsk::ValidationError => e
      message = e.is_a?(Llm::StructuredAsk::ValidationError) ? "Judge output failed schema validation: #{e.message}" : e.message
      EvalResult.create!(eval_run: eval_run, eval_case: eval_case, passed: false, error_message: message, latency_ms: elapsed_ms(started))
    end
    private_class_method :run_agent_case

    def self.observe_agent(company, eval_case)
      input = eval_case.input
      person = if input["person_email"]
        company.people.find_by(email: input["person_email"]) or raise ActiveRecord::RecordNotFound, "Nobody with the email #{input['person_email']} in this company"
      else
        company.people.find(input.fetch("person_id"))
      end

      conversation_id = SecureRandom.uuid
      Array(input["history"]).each_with_index do |turn, i|
        company.agent_runs.create!(person: person, conversation_id: conversation_id, message: turn["message"], final_text: turn["final_text"],
          status: "completed", created_at: (Array(input["history"]).size - i).hours.ago)
      end
      agent_run = company.agent_runs.create!(person: person, conversation_id: conversation_id, message: input.fetch("message"))
      Agent::Runner.call(agent_run)
      agent_run.reload

      {
        status: agent_run.status, error: agent_run.error_message, final_text: agent_run.final_text,
        tool_calls: agent_run.agent_steps.select { _1.kind == "tool" }.map { { "name" => _1.tool_name, "input" => _1.input, "output" => _1.output } }
      }
    end
    private_class_method :observe_agent

    def self.elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    private_class_method :elapsed_ms
  end
end
