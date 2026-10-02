module Rules
  class Engine
    Decision = Data.define(:outcome, :rule_keys, :approvers, :errors, :explanation)
    SEVERITY = { "reject" => 3, "require_approval" => 2, "auto_approve" => 1 }.freeze
    DEFAULT_ACTION = { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] }.freeze

    def initialize(snapshot)
      @g = snapshot
      @resolver = Org::Resolver.new(snapshot)
    end

    def evaluate(request, rules)
      ctx = Context.build(request, @g)
      matched = rules.select { Condition.match?(_1.conditions, ctx) }
      winner = matched.max_by { [ _1.priority, SEVERITY.fetch(_1.actions["decision"], 0) ] }
      action = winner&.actions || DEFAULT_ACTION

      approvers, errors = resolve_all(action["approvers"] || [], request.requester_id)
      outcome = errors.any? ? "blocked" : action["decision"]

      Decision.new(outcome, matched.map(&:key), approvers, errors, Explainer.call(winner, ctx))
    end

    private

    def resolve_all(references, requester_id)
      approvers = []
      errors = []

      references.each do |reference|
        result = @resolver.resolve(reference, requester_id: requester_id)
        approvers.concat(result.person_ids)
        errors << result.error if result.error
      end

      [ approvers.uniq, errors ]
    end
  end
end
