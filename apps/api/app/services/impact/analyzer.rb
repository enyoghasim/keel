module Impact
  # Answers "if we apply this org change, whose requests route differently,
  # and will anything break?" with no LLM involved (SPEC.md section 10).
  #
  # `scenarios` stands in for "every request kind with a representative
  # payload" — plain `{payload:, rules:}` hashes, since the rules/policies
  # tables don't exist yet (same stand-in pattern as Rules::RuleDefinition).
  class Analyzer
    Classification = Data.define(:kind, :person_id, :before, :after)
    Report = Data.define(:rerouted, :broken, :self_approval, :approval_load_changes)

    def self.call(snapshot:, diff:, scenarios:)
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
        approval_load_changes: approval_load_changes(results)
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
  end
end
