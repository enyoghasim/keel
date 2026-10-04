module Agent
  module Tools
    # Asks Rules::Engine what policy says about a hypothetical request from
    # the current person — the only way the agent may state a policy
    # outcome (SPEC.md section 9). Cites the handbook quote and page of
    # every rule that matched.
    class CheckPolicy < Base
      tool_name "check_policy"
      description "Check what company policy decides for a request the current person might make, without " \
                  "creating it. Returns the decision (auto_approve, require_approval, reject or blocked), who would " \
                  "approve, and the handbook quotes and pages it's based on. Always use this before stating a policy outcome."
      params({
        type: "object", additionalProperties: false, required: %w[request_kind payload],
        properties: { request_kind: { type: "string", enum: REQUEST_KINDS }, payload: PAYLOAD_SCHEMA }
      })

      def execute(request_kind:, payload:)
        decision = Rules::Engine.new(Org::GraphSnapshot.load(company)).evaluate(
          Rules::RequestInput.new(requester_id: person.id, payload: payload.to_h.stringify_keys),
          company.active_rule_definitions(request_kind)
        )

        {
          "decision" => decision.outcome,
          "explanation" => decision.explanation,
          "approvers" => company.people.where(id: decision.approvers).includes(:department).map { person_summary(_1) },
          "errors" => decision.errors,
          "citations" => citations(request_kind, decision.rule_keys),
          "policy_id" => company.policies.find_by(category: request_kind, status: "active")&.id
        }
      end

      private

      def citations(request_kind, rule_keys)
        Rule.joins(:policy).includes(:source_chunk)
            .where(policies: { company_id: company.id, category: request_kind, status: "active" }, key: rule_keys)
            .map { { "rule" => _1.key, "quote" => _1.source_quote, "page" => _1.source_chunk&.page } }
      end
    end
  end
end
