module Impact
  # Runs Impact::Analyzer for an org diff against a company's live graph,
  # active rules and open step runs, and returns the report as the JSON
  # stored on a ChangeProposal (SPEC.md section 10). Shared by the HTTP
  # controller and the agent's propose_org_change tool so both front doors
  # compute impact identically — there is no LLM in here.
  class OrgImpact
    def self.call(company:, diff:)
      report = Analyzer.call(
        snapshot: Org::GraphSnapshot.load(company), diff: diff,
        scenarios: scenarios(company), pending_step_runs: pending_step_runs(company)
      )

      {
        "rerouted" => report.rerouted.map { serialize_classification(_1) },
        "broken" => report.broken.map { serialize_classification(_1) },
        "self_approval" => report.self_approval.map { serialize_classification(_1) },
        "approval_load_changes" => report.approval_load_changes,
        "rerouted_in_flight" => report.rerouted_in_flight
      }
    end

    # Representative payloads standing in for "every request kind" — a
    # small/medium/large expense and a week-ish of leave booked a month ahead — evaluated
    # against the company's actual active rules.
    def self.scenarios(company)
      expense_rules = company.active_rule_definitions("expense")
      leave_rules = company.active_rule_definitions("leave")

      [
        { payload: { "amount_eur" => 100 }, rules: expense_rules },
        { payload: { "amount_eur" => 800 }, rules: expense_rules },
        { payload: { "amount_eur" => 3000 }, rules: expense_rules },
        { payload: { "days" => 5, "notice_days" => 30 }, rules: leave_rules }
      ]
    end
    private_class_method :scenarios

    def self.pending_step_runs(company)
      StepRun.where(status: "pending").joins(workflow_run: :request).where(requests: { company_id: company.id })
    end
    private_class_method :pending_step_runs

    def self.serialize_classification(classification)
      {
        "person_id" => classification.person_id,
        "before" => serialize_decision(classification.before),
        "after" => serialize_decision(classification.after)
      }
    end
    private_class_method :serialize_classification

    def self.serialize_decision(decision)
      {
        "outcome" => decision.outcome, "rule_keys" => decision.rule_keys, "approvers" => decision.approvers,
        "errors" => decision.errors, "explanation" => decision.explanation
      }
    end
    private_class_method :serialize_decision
  end
end
