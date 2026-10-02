module Impact
  # The impact report for a workflow change, stored on a ChangeProposal
  # (SPEC.md section 10): a step-level diff, and — by dry-running the old
  # and new workflow for every person under a few representative requests —
  # whose steps change and whether any new step resolves to nobody. No LLM.
  class WorkflowImpact
    SAMPLE_LIMIT = 25

    # Representative payloads per request kind, like OrgImpact.scenarios.
    SCENARIO_PAYLOADS = {
      "expense" => [ { "amount_eur" => 100 }, { "amount_eur" => 800 }, { "amount_eur" => 3000 } ],
      "leave" => [ { "days" => 5, "notice_days" => 30 } ],
      "equipment" => [ { "amount_eur" => 500 }, { "amount_eur" => 2000 } ]
    }.freeze

    def self.call(company:, workflow:, after_steps:)
      new(company, workflow, after_steps).call
    end

    def initialize(company, workflow, after_steps)
      @company = company
      @workflow = workflow
      @after_steps = after_steps
    end

    def call
      kind = @workflow.trigger["request_kind"]
      rules = @company.active_rule_definitions(kind)
      runtime = Workflows::Runtime.new(Org::GraphSnapshot.load(@company))
      after_workflow = @workflow.dup.tap { _1.steps = @after_steps }

      changes = []
      broken = Hash.new { |hash, key| hash[key] = [] }
      @company.people.pluck(:id).each do |person_id|
        SCENARIO_PAYLOADS.fetch(kind, [ {} ]).each do |payload|
          before = matched_steps(runtime, @workflow, person_id, payload, rules)
          after = matched_steps(runtime, after_workflow, person_id, payload, rules)
          next if before == after

          changes << { "person_id" => person_id, "payload" => payload, "before" => before, "after" => after }
          (after - before).each { broken[[ _1["step_key"], _1["reference"] ]] << person_id if _1["person_id"].nil? }
        end
      end

      {
        "steps" => step_diff, "scenarios_run" => @company.people.count * SCENARIO_PAYLOADS.fetch(kind, [ {} ]).size,
        "affected_count" => changes.pluck("person_id").uniq.size, "affected" => changes.first(SAMPLE_LIMIT),
        "broken" => broken.map { |(key, reference), ids| { "step_key" => key, "reference" => reference, "person_count" => ids.uniq.size } },
        "in_flight" => in_flight
      }
    end

    private

    # The steps that would fire for this person and request, as
    # {step_key, reference, person_id} — what Runtime#dry_run resolves.
    def matched_steps(runtime, workflow, person_id, payload, rules)
      runtime.dry_run(workflow, requester_id: person_id, payload: payload, rules: rules).steps.filter_map do |step|
        next unless step.matched && step.type != "system"

        { "step_key" => step.step_key, "reference" => step.reference, "person_id" => step.resolved_person_id }
      end
    end

    def step_diff
      before = @workflow.steps.index_by { _1["key"] }
      after = @after_steps.index_by { _1["key"] }
      common = before.keys & after.keys
      before_order = before.keys & common
      after_order = after.keys & common

      {
        "added" => after.keys - before.keys, "removed" => before.keys - after.keys,
        "changed" => common.reject { before[_1] == after[_1] },
        "moved" => after_order.reject { before_order.index(_1) == after_order.index(_1) }
      }
    end

    # Open step runs of this workflow waiting on a step the change removes.
    def in_flight
      removed = step_diff["removed"]
      return 0 if removed.empty?

      StepRun.where(status: "pending", step_key: removed).joins(:workflow_run).where(workflow_runs: { workflow_id: @workflow.id }).count
    end
  end
end
