module Evals
  # Turns an approver's override of an engine decision (SPEC.md section 12's
  # production feedback loop) into a candidate policy_extraction case. The
  # input is the handbook text behind the rules that decided the request —
  # their verbatim source quotes — plus what those rules saw and the human's
  # reason; a reviewer writes the rules that text should have produced
  # (`expected` stays empty) and adds it to the suite. Per AGENTS.md rule 1
  # no person's name is stored, only the attributes the engine looked at.
  class OverrideCandidate
    def self.call(step_run:)
      request = step_run.workflow_run.request
      quotes = quotes_for(request)
      return nil if quotes.empty?

      eval_case = EvalCase.find_or_initialize_by(suite: "policy_extraction", key: "override_step_run_#{step_run.id}")
      eval_case.assign_attributes(
        input: input_for(request, quotes), notes: "Approver override: #{step_run.override_reason}", source: "override",
        status: eval_case.new_record? ? "candidate" : eval_case.status
      )
      eval_case.save!
      eval_case
    end

    def self.quotes_for(request)
      Rule.joins(:policy)
          .where(policies: { company_id: request.company_id, category: request.kind }, key: request.matched_rule_ids)
          .order(:id).pluck(:source_quote).uniq
    end
    private_class_method :quotes_for

    def self.input_for(request, quotes)
      requester = request.requester

      {
        "category" => request.kind, "passage" => quotes.join(" "),
        "request" => { "payload" => request.payload, "location" => requester.location, "department" => requester.department&.name },
        "engine_decision" => request.decision, "final_status" => request.status
      }
    end
    private_class_method :input_for
  end
end
