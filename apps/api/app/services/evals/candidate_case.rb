module Evals
  # Turns a production signal about an agent run — a thumbs-down, a
  # rejected proposal — into a candidate agent eval case (SPEC.md section
  # 12's production feedback loop): the message, the person, the observed
  # trace and the human's note. `expected` stays empty: a reviewer fills it
  # in on the Trust page before the case joins the suite, because guessing
  # it would be the AI marking its own homework.
  module CandidateCase
    # Creates the candidate, or refreshes its input and notes if the same
    # signal fires again. A case a reviewer already made active is only
    # refreshed, never demoted; an archived one comes back as a candidate.
    def self.upsert(agent_run, key:, notes:, extra_input: {})
      eval_case = EvalCase.find_or_initialize_by(suite: "agent", key: key)
      eval_case.assign_attributes(input: input_for(agent_run).merge(extra_input), notes: notes)
      eval_case.assign_attributes(source: "generated", status: "candidate") if eval_case.new_record? || eval_case.status == "archived"
      eval_case.save!
      eval_case
    end

    # A reviewer's decision (an active case) is never undone by a later signal.
    def self.archive_if_candidate(key)
      EvalCase.where(suite: "agent", key: key, status: "candidate").update_all(status: "archived")
    end

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
  end
end
