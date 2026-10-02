module KeelMcp
  module Tools
    class CheckPolicy < MCP::Tool
      extend ToolAdapter

      tool_name "check_policy"
      description "Check what company policy decides for a request the token's owner might make — e.g. an expense or " \
                  "leave — without creating it. Returns the decision, who would approve, and the handbook quote and page. Read-only."
      input_schema(
        properties: {
          request_kind: { type: "string", enum: Agent::Tools::Base::REQUEST_KINDS },
          payload: Agent::Tools::Base::PAYLOAD_SCHEMA
        },
        required: %w[request_kind payload]
      )

      def self.call(server_context:, **arguments) = run_agent_tool(Agent::Tools::CheckPolicy, arguments, server_context: server_context)
    end
  end
end
