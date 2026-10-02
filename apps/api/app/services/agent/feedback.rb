module Agent
  # Thumbs up/down on an agent answer (SPEC.md section 9's Feedback). A
  # thumbs-down also creates — or updates — a candidate eval case for the
  # agent suite with the message, the observed trace and the person's note
  # (SPEC.md section 12's production feedback loop); a reviewer fills in the
  # expected outcome and promotes it from the Trust page. The case's
  # `expected` stays empty here: guessing it would be the AI marking its own
  # homework.
  class Feedback
    RATINGS = %w[up down].freeze
    REASONS = %w[wrong_answer wrong_action unclear other].freeze

    def self.call(agent_run:, rating:, reason: nil, note: nil)
      raise ArgumentError, "rating must be one of #{RATINGS.join(', ')}" unless RATINGS.include?(rating)
      raise ArgumentError, "reason must be one of #{REASONS.join(', ')}" if reason.present? && REASONS.exclude?(reason)
      raise ArgumentError, "Feedback is only for a finished answer" unless agent_run.status == "completed"

      down = rating == "down"
      agent_run.update!(feedback: rating, feedback_reason: down ? reason.presence : nil, feedback_note: down ? note.presence : nil)
      down ? upsert_candidate(agent_run) : archive_candidate(agent_run)
      agent_run
    end

    def self.case_key(agent_run) = "feedback_run_#{agent_run.id}"

    def self.upsert_candidate(agent_run)
      Evals::CandidateCase.upsert(agent_run, key: case_key(agent_run), notes: notes_for(agent_run))
    end
    private_class_method :upsert_candidate

    def self.archive_candidate(agent_run) = Evals::CandidateCase.archive_if_candidate(case_key(agent_run))
    private_class_method :archive_candidate

    def self.notes_for(agent_run)
      label = "Thumbs-down (#{(agent_run.feedback_reason || 'no reason given').humanize.downcase})"
      agent_run.feedback_note.present? ? "#{label}: #{agent_run.feedback_note}" : label
    end
    private_class_method :notes_for
  end
end
