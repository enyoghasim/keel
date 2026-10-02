module KeelMcp
  module Tools
    class OrgLookup < MCP::Tool
      extend ToolAdapter

      tool_name "org_lookup"
      description "Look up one person's place in the org chart: their reporting line, direct reports, department head and roles. Read-only."
      input_schema(
        properties: { person_id: { type: "integer", description: "The person's id" } },
        required: %w[person_id]
      )

      def self.call(server_context:, **arguments) = run_agent_tool(Agent::Tools::OrgLookup, arguments, server_context: server_context)
    end
  end
end
