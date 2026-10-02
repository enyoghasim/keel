module KeelMcp
  module Tools
    # The one write: files a real leave request for the token's owner through
    # Agent::Tools::CreateRequest, so it takes the normal policy engine and
    # approval workflow. Dates become the engine's payload (working days and
    # notice) here, deterministically — the client's model never computes them.
    class RequestLeave < MCP::Tool
      extend ToolAdapter

      tool_name "request_leave"
      description "Request annual leave for the token's owner between two dates (inclusive). Creates a real request that goes " \
                  "through Keel's approval workflow; the result says who has to approve it."
      input_schema(
        properties: {
          start_date: { type: "string", format: "date", description: "First day of leave, YYYY-MM-DD" },
          end_date: { type: "string", format: "date", description: "Last day of leave, YYYY-MM-DD" }
        },
        required: %w[start_date end_date]
      )

      def self.call(server_context:, start_date:, end_date:)
        first, last = Date.iso8601(start_date), Date.iso8601(end_date)
        raise ArgumentError, "end_date must not be before start_date" if last < first

        payload = {
          "days" => (first..last).count { !_1.saturday? && !_1.sunday? }, "notice_days" => (first - Date.current).to_i,
          "start_date" => start_date, "end_date" => end_date, "leave_type" => "annual"
        }
        run_agent_tool(Agent::Tools::CreateRequest, { "request_kind" => "leave", "payload" => payload }, server_context: server_context)
      rescue ArgumentError => e
        MCP::Tool::Response.new([ { type: "text", text: { "error" => e.message }.to_json } ], error: true)
      end
    end
  end
end
