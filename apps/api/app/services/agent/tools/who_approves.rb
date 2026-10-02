module Agent
  module Tools
    # Previews how a request would route right now (Workflows::Runtime#dry_run):
    # nothing is saved. Complements check_policy, which answers the
    # decision; this answers the whole route, including task and notify steps.
    class WhoApproves < Base
      tool_name "who_approves"
      description "Preview who would approve a request, and every step it would pass through, without creating it. " \
                  "Defaults to the current person as requester; pass person_id to route it for someone else."
      params({
        type: "object", additionalProperties: false, required: %w[request_kind payload],
        properties: {
          request_kind: { type: "string", enum: REQUEST_KINDS },
          payload: PAYLOAD_SCHEMA,
          person_id: { type: "integer", description: "Requester, if not the current person" }
        }
      })

      def execute(request_kind:, payload:, person_id: nil)
        requester = person_id ? company.people.find_by(id: person_id) : person
        return { "error" => "Person #{person_id} not found in this company." } if requester.nil?

        workflow = company.workflows.where(status: "active").detect { _1.trigger["request_kind"] == request_kind }
        return { "error" => "There is no active workflow for #{request_kind} requests." } if workflow.nil?

        result = Workflows::Runtime.new(Org::GraphSnapshot.load(company)).dry_run(
          workflow, requester_id: requester.id, payload: payload.to_h.stringify_keys, rules: company.active_rule_definitions(request_kind)
        )
        people = company.people.includes(:department).where(id: result.steps.filter_map(&:resolved_person_id)).index_by(&:id)

        {
          "outcome" => result.outcome,
          "errors" => result.errors,
          "steps" => result.steps.map do |step|
            { "step" => step.step_key, "type" => step.type, "applies" => step.matched, "person" => person_summary(people[step.resolved_person_id]) }
          end
        }
      end
    end
  end
end
