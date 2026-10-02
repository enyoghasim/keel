module KeelMcp
  module Tools
    class WhoApproves < MCP::Tool
      extend ToolAdapter

      tool_name "who_approves"
      description "Preview who would approve a request, and every step it would pass through, without creating it. " \
                  "Read-only; asks as the person the access token belongs to."
      input_schema(
        properties: {
          request_kind: { type: "string", enum: Agent::Tools::Base::REQUEST_KINDS },
          payload: Agent::Tools::Base::PAYLOAD_SCHEMA
        },
        required: %w[request_kind payload]
      )

      def self.call(server_context:, **arguments) = run_agent_tool(Agent::Tools::WhoApproves, arguments, server_context: server_context)
    end
  end
end
