module KeelMcp
  # Shared by every MCP tool: runs the named Agent::Tools class as the
  # token's owner and returns its JSON result as MCP text content, marking a
  # tool-level {"error": ...} as an MCP error result so the client's model
  # sees it as a failure rather than data. Every call is recorded as an
  # McpCall.
  module ToolAdapter
    def run_agent_tool(agent_tool, arguments, server_context:)
      person = server_context.fetch(:person)
      context = Agent::Context.new(company: person.company, person: person, agent_run: nil)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      json = agent_tool.new(context).call(arguments)
      parsed = JSON.parse(json)
      error = parsed.is_a?(Hash) && parsed.key?("error")

      McpCall.record!(
        person: person, token: server_context[:token], tool_name: agent_tool.tool_name, input: arguments.deep_stringify_keys, output: parsed,
        is_error: error, latency_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      )
      MCP::Tool::Response.new([ { type: "text", text: json } ], error: error)
    end
  end
end
