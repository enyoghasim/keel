module Impact
  # Answers "if we apply this org change, whose requests route differently,
  # and will anything break?" with no LLM involved (SPEC.md section 10).
  #
  # `scenarios` stands in for "every request kind with a representative
  # payload" — plain `{payload:, rules:}` hashes, since the rules/policies
  # tables don't exist yet (same stand-in pattern as Rules::RuleDefinition).
  class Analyzer
    Classification = Data.define(:kind, :person_id, :before, :after)
    Report = Data.define(:rerouted, :broken, :self_approval, :approval_load_changes, :rerouted_in_flight)

    def self.call(snapshot:, diff:, scenarios:, pending_step_runs: [])
      before_snapshot = snapshot
      after_snapshot = snapshot.with_change(diff)
      engine_before = Rules::Engine.new(before_snapshot)
      engine_after = Rules::Engine.new(after_snapshot)

      results = before_snapshot.people.keys.flat_map do |person_id|
        scenarios.map do |scenario|
          request = Rules::RequestInput.new(requester_id: person_id, payload: scenario[:payload])
          [
            person_id,
            engine_before.evaluate(request, scenario[:rules]),
            engine_after.evaluate(request, scenario[:rules])
          ]
        end
      end

      changes = results.filter_map { |person_id, before, after| classify(person_id, before, after) }

      Report.new(
        rerouted: changes.select { _1.kind == :rerouted },
        broken: changes.select { _1.kind == :broken },
        self_approval: changes.select { _1.kind == :self_approval },
        approval_load_changes: approval_load_changes(results),
        rerouted_in_flight: rerouted_in_flight(pending_step_runs, before_snapshot, after_snapshot)
      )
    end

    def self.classify(person_id, before, after)
      return nil if before.approvers.sort == after.approvers.sort && before.errors.sort == after.errors.sort

      kind = if after.errors.include?("self-approval") && !before.errors.include?("self-approval")
        :self_approval
      elsif after.errors.any? { _1.end_with?("resolved to nobody") } && before.errors.none? { _1.end_with?("resolved to nobody") }
        :broken
      else
        :rerouted
      end

      Classification.new(kind, person_id, before, after)
    end
    private_class_method :classify

    def self.approval_load_changes(results)
      before_counts = Hash.new(0)
      after_counts = Hash.new(0)

      results.each do |_person_id, before, after|
        before.approvers.each { before_counts[_1] += 1 }
        after.approvers.each { after_counts[_1] += 1 }
      end

      (before_counts.keys | after_counts.keys).filter_map do |approver_id|
        before_n, after_n = before_counts[approver_id], after_counts[approver_id]
        next if before_n == after_n

        { approver_id: approver_id, before: before_n, after: after_n }
      end
    end
    private_class_method :approval_load_changes

    # SPEC.md section 10 point 4: a step run still waiting on an action,
    # whose reference would resolve to a different person once the change
    # is applied. A step already pinned to a concrete person (an approval
    # step's "person:ID" reference, set from the engine's decision at
    # submission time) never reroutes — only role/manager-style references
    # that depend on the live org graph can.
    def self.rerouted_in_flight(pending_step_runs, before_snapshot, after_snapshot)
      resolver_before = Org::Resolver.new(before_snapshot)
      resolver_after = Org::Resolver.new(after_snapshot)

      pending_step_runs.filter_map do |step_run|
        requester_id = step_run.workflow_run.request.requester_id
        before = resolver_before.resolve(step_run.reference, requester_id: requester_id)
        after = resolver_after.resolve(step_run.reference, requester_id: requester_id)
        next if before.person_ids.sort == after.person_ids.sort

        { step_run_id: step_run.id, before_person_ids: before.person_ids, after_person_ids: after.person_ids }
      end
    end
    private_class_method :rerouted_in_flight
  end
end
