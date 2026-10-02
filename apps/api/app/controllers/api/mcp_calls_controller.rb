module Api
  # The signed-in person's recent MCP tool calls (SPEC.md section 13).
  class McpCallsController < ApplicationController
    include CompanyScoped

    RECENT_LIMIT = 20

    before_action :require_current_person!

    def index
      calls = current_person.mcp_calls.includes(:personal_access_token).order(created_at: :desc, id: :desc).limit(RECENT_LIMIT)
      render_success(data: calls.map(&:as_payload))
    end
  end
end
