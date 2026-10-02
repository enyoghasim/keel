module Evals
  # Promoting a prompt version (SPEC.md section 12): a challenger becomes the
  # active prompt only if it doesn't regress any case the active version
  # passes, judged on each version's latest completed eval run — unless a
  # human confirms. A challenger that was never evaluated is blocked too, so
  # nobody promotes blind.
  class Promotion
    class Blocked < StandardError
      attr_reader :regressions

      def initialize(message, regressions: [])
        super(message)
        @regressions = regressions
      end
    end

    # Keys of the cases the active version passes that the challenger fails
    # (or never ran); nil when the challenger has no completed run to judge.
    def self.regressions(challenger:, company:)
      active = PromptVersion.active_for(challenger.key)
      return [] if active.nil? || active == challenger

      challenger_run = latest_run(challenger, company)
      return nil if challenger_run.nil?

      active_run = latest_run(active, company)
      return [] if active_run.nil?

      passed_by_active = passed_case_ids(active_run)
      passed_by_challenger = passed_case_ids(challenger_run)
      EvalCase.where(id: passed_by_active - passed_by_challenger).order(:key).pluck(:key)
    end

    def self.call(prompt_version:, company:, confirm: false)
      unless confirm
        regressions = regressions(challenger: prompt_version, company: company)
        raise Blocked, "This version hasn't been evaluated yet — run its suite first." if regressions.nil?
        raise Blocked.new("This version regresses #{regressions.size} #{'case'.pluralize(regressions.size)} the active version passes: #{regressions.join(', ')}.", regressions: regressions) if regressions.any?
      end

      prompt_version.promote!
    end

    def self.latest_run(prompt_version, company)
      company.eval_runs.where(prompt_version: prompt_version, status: "completed").order(finished_at: :desc, id: :desc).first
    end
    private_class_method :latest_run

    def self.passed_case_ids(eval_run) = eval_run.eval_results.where(passed: true).pluck(:eval_case_id)
    private_class_method :passed_case_ids
  end
end
