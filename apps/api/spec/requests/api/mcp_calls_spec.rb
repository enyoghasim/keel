require "rails_helper"

RSpec.describe "Api::McpCalls", type: :request do
  let(:company) { create(:company) }
  let(:person) { create(:person, company: company) }

  it "lists the signed-in person's own MCP calls, newest first, with what went in and came out" do
    older = create(:mcp_call, company: company, person: person, created_at: 2.hours.ago)
    newer = create(:mcp_call, company: company, person: person, tool_name: "who_approves", created_at: 1.hour.ago, is_error: true)
    create(:mcp_call, company: company) # someone else's
    sign_in(person)

    get "/api/companies/#{company.id}/mcp_calls"

    data = response.parsed_body["data"]
    expect(data.map { _1["id"] }).to eq([ newer.id, older.id ])
    expect(data.first).to include("tool_name" => "who_approves", "is_error" => true, "latency_ms" => 12, "token_name" => nil)
    expect(data.last).to include("input" => older.input, "output" => older.output)
  end

  it "names the token a call came in on" do
    token = create(:personal_access_token, person: person, name: "Claude Desktop")
    create(:mcp_call, company: company, person: person, personal_access_token: token)
    sign_in(person)

    get "/api/companies/#{company.id}/mcp_calls"

    expect(response.parsed_body["data"].first["token_name"]).to eq("Claude Desktop")
  end

  it "requires sign-in" do
    get "/api/companies/#{company.id}/mcp_calls"

    expect(response).to have_http_status(:unauthorized)
  end
end
