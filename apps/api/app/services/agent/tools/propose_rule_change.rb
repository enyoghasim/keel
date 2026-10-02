module Agent
  module Tools
    # The rule half of the "Change" kind (SPEC.md section 9): asks
    # Assemble::RuleRecompiler to rewrite the affected rule, backtests the
    # rewrite against past requests (Impact::RuleImpact) and records a
    # pending ChangeProposal linked to this run's trace. The live rules
    # don't change until a person approves it on /proposals (AGENTS.md
    # rule 2). Idempotent within a run.
    class ProposeRuleChange < Base
      tool_name "propose_rule_change"
      description "Propose a change to a company policy, e.g. 'raise the auto-approve limit to €800'. The affected " \
                  "rule is rewritten and replayed against past requests to show which decisions would flip. This " \
                  "does NOT change the policy: an HR admin must approve the proposal. Only hr_admin people can use it."
      params({
        type: "object", additionalProperties: false, required: %w[policy_id instruction],
        properties: {
          policy_id: { type: "integer", description: "The policy to change (check_policy results name the rule and policy)" },
          instruction: { type: "string", description: "The change in plain language, e.g. 'raise the auto-approve limit to €800'" }
        }
      })

      def initialize(context)
        super
        @created = {}
      end

      def execute(policy_id:, instruction:)
        require_hr_admin!("propose policy changes")
        policy = company.policies.find_by(id: policy_id) or return { "error" => "Policy #{policy_id} not found in this company." }

        proposal = (@created[[ policy.id, instruction ]] ||= create_proposal(policy, instruction))
        return { "error" => "That instruction would not change any rule of #{policy.title}." } if proposal.nil?

        summarize(proposal)
      end

      private

      # nil when the recompiled policy is identical to the current one.
      def create_proposal(policy, instruction)
        changed = Assemble::RuleRecompiler.call(policy: policy, instruction: instruction)
        return nil if changed.empty?

        before = policy.rules.where(status: "active", key: changed.keys).order(:id)
        company.change_proposals.create!(
          kind: "rule", title: "#{policy.title}: #{instruction}".truncate(120), proposed_by: "agent", agent_run: context.agent_run,
          diff: { "policy_id" => policy.id, "instruction" => instruction, "before" => before.map { rule_json(_1) },
                  "after" => before.map { rule_json(_1, changed.fetch(_1.key)) } },
          impact: Impact::RuleImpact.call(company: company, policy: policy, after_rules: changed)
        )
      end

      # The rewritten rule keeps its original handbook quote and chunk: the
      # rewrite changes what the rule does, not where the policy came from.
      def rule_json(rule, definition = nil)
        {
          "key" => rule.key, "priority" => definition&.priority || rule.priority,
          "conditions" => definition&.conditions || rule.conditions, "actions" => definition&.actions || rule.actions,
          "source_quote" => rule.source_quote, "source_chunk_id" => rule.source_chunk_id
        }
      end

      def summarize(proposal)
        backtest = proposal.impact["backtest"]

        {
          "proposal_id" => proposal.id, "status" => proposal.status, "link" => "/proposals",
          "total" => backtest["total"], "flipped" => backtest["flipped_count"], "new_conflicts" => backtest["new_conflicts"].size, "summary" => backtest["summary"],
          "note" => "The policy has not changed yet. An HR admin has to review and approve this proposal on the Proposals page."
        }
      end
    end
  end
end
