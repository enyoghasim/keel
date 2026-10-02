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
      eval_case = EvalCase.find_or_initialize_by(suite: "agent", key: case_key(agent_run))
      eval_case.assign_attributes(input: input_for(agent_run), notes: notes_for(agent_run))
      eval_case.assign_attributes(source: "generated", status: "candidate") if eval_case.new_record? || eval_case.status == "archived"
      eval_case.save!
    end
    private_class_method :upsert_candidate

    # A reviewer's decision (an active case) is never undone by a later click.
    def self.archive_candidate(agent_run)
      EvalCase.where(suite: "agent", key: case_key(agent_run), status: "candidate").update_all(status: "archived")
    end
    private_class_method :archive_candidate

    def self.input_for(agent_run)
      tool_steps = agent_run.agent_steps.select { _1.kind == "tool" }

      {
        "message" => agent_run.message, "person_id" => agent_run.person_id, "agent_run_id" => agent_run.id,
        "observed" => {
          "final_text" => agent_run.final_text,
          "tool_calls" => tool_steps.map { { "name" => _1.tool_name, "input" => _1.input, "output" => _1.output } }
        }
      }
    end
    private_class_method :input_for

    def self.notes_for(agent_run)
      label = "Thumbs-down (#{(agent_run.feedback_reason || 'no reason given').humanize.downcase})"
      agent_run.feedback_note.present? ? "#{label}: #{agent_run.feedback_note}" : label
    end
    private_class_method :notes_for
  end
end
