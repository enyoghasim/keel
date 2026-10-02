module KeelMcp
  # The four agent tools Keel exposes over MCP, each a thin adapter over
  # the Agent::Tools class of the same name — one implementation, two front
  # doors (SPEC.md section 13).
  module Server
    TOOLS = [ Tools::WhoApproves, Tools::CheckPolicy, Tools::OrgLookup, Tools::RequestLeave ].freeze

    def self.build(person)
      MCP::Server.new(
        name: "keel", version: "1.0.0", tools: TOOLS,
        server_context: { person: person }
      )
    end
  end
end
