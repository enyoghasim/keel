module Rules
  class Engine
    Decision = Data.define(:outcome, :rule_keys, :approvers, :errors, :explanation)
    SEVERITY = { "reject" => 3, "require_approval" => 2, "auto_approve" => 1 }.freeze
    DEFAULT_ACTION = { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] }.freeze

    Choice = Data.define(:winner, :action, :rule_keys)

    # The rule-selection half of #evaluate, on a ready-made context: the
    # highest priority wins, ties go to the more restrictive action, and
    # no match means the default action. Public so the eval harness can probe
    # rule sets with synthetic contexts through the engine's own logic.
    def self.decide(context, rules)
      matched = rules.select { Condition.match?(_1.conditions, context) }
      winner = matched.max_by { [ _1.priority, SEVERITY.fetch(_1.actions["decision"], 0) ] }

      Choice.new(winner, winner&.actions || DEFAULT_ACTION, matched.map(&:key))
    end

    def initialize(snapshot)
      @g = snapshot
      @resolver = Org::Resolver.new(snapshot)
    end

    def evaluate(request, rules)
      ctx = Context.build(request, @g)
      choice = self.class.decide(ctx, rules)
      action = choice.action

      approvers, errors = resolve_all(action["approvers"] || [], request.requester_id)
      outcome = errors.any? ? "blocked" : action["decision"]

      Decision.new(outcome, choice.rule_keys, approvers, errors, Explainer.call(choice.winner, ctx))
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
