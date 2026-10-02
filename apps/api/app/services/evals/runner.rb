module Evals
  # Runs one EvalRun (SPEC.md section 12): every active case in the suite
  # goes through the same AI service production uses, and is scored by a
  # deterministic scorer. Only the insights suite is runnable so far —
  # policy_extraction and agent need their own scorers (behavioural probes
  # and LLM-as-judge) before they can be.
  class Runner
    SUITES = {
      "insights" => ->(eval_run, eval_case) { run_insights_case(eval_run, eval_case) }
    }.freeze

    def self.call(eval_run, &on_progress)
      run_case = SUITES.fetch(eval_run.suite) { raise ArgumentError, "the #{eval_run.suite} suite isn't runnable yet" }
      cases = EvalCase.active.where(suite: eval_run.suite).order(:key).to_a
      eval_run.update!(status: "running", started_at: Time.current, model: RubyLLM.config.default_model, cases_count: cases.size)

      cases.each_with_index do |eval_case, i|
        result = run_case.call(eval_run, eval_case)
        on_progress&.call(result, i + 1, cases.size)
      end

      passed = eval_run.eval_results.where(passed: true).count
      eval_run.update!(status: "completed", finished_at: Time.current, passed_count: passed,
        accuracy: cases.empty? ? nil : passed.fdiv(cases.size))
      eval_run
    end

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

    def self.elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    private_class_method :elapsed_ms
  end
end
