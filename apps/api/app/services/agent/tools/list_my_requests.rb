module Agent
  module Tools
    # The current person's own requests and where each one stands.
    class ListMyRequests < Base
      LIMIT = 20

      tool_name "list_my_requests"
      description "List the current person's own recent requests (newest first, up to 20) with their status, " \
                  "decision and who each pending one is waiting on."
      params({
        type: "object", additionalProperties: false,
        properties: { status: { type: "string", enum: %w[pending approved rejected blocked], description: "Only requests in this status" } }
      })

      def execute(status: nil)
        scope = company.requests.where(requester: person).includes(workflow_run: { step_runs: :resolved_person })
        scope = scope.where(status: status) if status
        { "requests" => scope.order(created_at: :desc, id: :desc).limit(LIMIT).map { summarise(_1) } }
      end

      private

      def summarise(request)
        waiting = request.workflow_run&.step_runs&.detect { _1.status == "pending" }
        {
          "id" => request.id, "kind" => request.kind, "payload" => request.payload, "status" => request.status,
          "decision" => request.decision, "submitted_at" => request.created_at.iso8601,
          "waiting_on" => waiting&.resolved_person&.name
        }
      end
    end
  end
end
