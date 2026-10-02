module KeelMcp
  # Shared by every MCP tool: runs the named Agent::Tools class as the
  # token's owner and returns its JSON result as MCP text content, marking a
  # tool-level {"error": ...} as an MCP error result so the client's model
  # sees it as a failure rather than data.
  module ToolAdapter
    def run_agent_tool(agent_tool, arguments, server_context:)
      person = server_context.fetch(:person)
      context = Agent::Context.new(company: person.company, person: person, agent_run: nil)
      json = agent_tool.new(context).call(arguments)
      parsed = JSON.parse(json)

      MCP::Tool::Response.new([ { type: "text", text: json } ], error: parsed.is_a?(Hash) && parsed.key?("error"))
    end
  end
end
