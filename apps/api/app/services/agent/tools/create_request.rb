module Agent
  module Tools
    # Submits a real request for the current person through
    # Workflows::Submission — the same path as the HTTP endpoint — and
    # reports who it's now waiting on. Idempotent within a run (SPEC.md
    # section 9): models sometimes repeat a call, and a repeat returns the
    # request already created rather than filing a second one.
    class CreateRequest < Base
      tool_name "create_request"
      description "Submit a real expense, leave or equipment request for the current person. The policy engine " \
                  "decides it and the approval workflow starts. Only call this when the person has clearly asked " \
                  "to submit something, not to check what would happen (use check_policy for that)."
      params({
        type: "object", additionalProperties: false, required: %w[request_kind payload],
        properties: { request_kind: { type: "string", enum: REQUEST_KINDS }, payload: PAYLOAD_SCHEMA }
      })

      def initialize(context)
        super
        @created = {}
      end

      def execute(request_kind:, payload:)
        payload = payload.to_h.stringify_keys
        key = [ request_kind, payload.sort.to_h ]
        @created[key] ||= Workflows::Submission.call(company: company, requester: person, kind: request_kind, payload: payload)

        summarize(@created[key].reload)
      end

      private

      def summarize(request)
        steps = request.workflow_run&.step_runs&.includes(:resolved_person)&.order(:id) || []

        {
          "request_id" => request.id, "kind" => request.kind, "status" => request.status, "decision" => request.decision,
          "steps" => steps.map do
            { "step" => _1.step_key, "status" => _1.status, "assignee" => _1.resolved_person&.name, "assignee_reference" => _1.reference }
          end
        }
      end
    end
  end
end
