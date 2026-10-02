require "rails_helper"

RSpec.describe "MCP endpoint", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # SPEC.md section 13: four of Keel's agent tools over the Model Context
  # Protocol, authenticated by a personal access token so "my leave" means
  # the token's owner. The tools are thin adapters over Agent::Tools::*.
  let(:company) { create(:company) }
  let(:manager) { create(:person, company: company, name: "Tunde Bakare") }
  let(:person) { create(:person, company: company, manager: manager) }
  let(:raw_token) { PersonalAccessToken.issue!(person, name: "Claude Desktop").last }
  let(:headers) do
    { "Authorization" => "Bearer #{raw_token}", "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
  end

  before do
    policy = create(:policy, company: company, category: "leave", status: "active")
    create(:rule, policy: policy, status: "active", key: "leave_needs_manager",
      conditions: { "field" => "payload.days", "op" => "gte", "value" => 1 },
      actions: { "decision" => "require_approval", "approvers" => [ "manager_of(requester)" ] })
    create(:workflow, company: company, status: "active", trigger: { "request_kind" => "leave" },
      steps: [ { "key" => "approval", "type" => "approval" } ])
  end

  def rpc(method, params = {}, id: 1, with: headers)
    post "/mcp", params: { jsonrpc: "2.0", id: id, method: method, params: params }.to_json, headers: with
    response.parsed_body
  end

  def tool_result(name, arguments)
    result = rpc("tools/call", { name: name, arguments: arguments })["result"]
    [ JSON.parse(result["content"].first["text"]), result ]
  end

  it "rejects a request without a valid personal access token" do
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: headers.except("Authorization")
    expect(response).to have_http_status(:unauthorized)

    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: headers.merge("Authorization" => "Bearer keel_pat_wrong")
    expect(response).to have_http_status(:unauthorized)
  end

  it "stops accepting a token once it's revoked" do
    token = PersonalAccessToken.find_by!(token_digest: PersonalAccessToken.digest(raw_token))
    token.update!(revoked_at: Time.current)

    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "initializes and lists exactly the four exposed tools" do
    expect(rpc("initialize", { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "test", version: "1" } })["result"]["serverInfo"]["name"]).to eq("keel")

    tools = rpc("tools/list")["result"]["tools"]

    expect(tools.map { _1["name"] }).to contain_exactly("who_approves", "check_policy", "org_lookup", "request_leave")
    expect(tools.map { _1["description"] }).to all(be_present)
  end

  it "answers who_approves for the token's owner" do
    data, = tool_result("who_approves", { request_kind: "leave", payload: { days: 5 } })

    expect(data["steps"].first["person"]).to include("name" => "Tunde Bakare")
  end

  it "answers check_policy with the engine's decision" do
    data, = tool_result("check_policy", { request_kind: "leave", payload: { days: 5 } })

    expect(data).to include("decision" => "require_approval")
    expect(data["approvers"].map { _1["name"] }).to eq([ "Tunde Bakare" ])
  end

  it "looks up the org around a person" do
    data, = tool_result("org_lookup", { person_id: person.id })

    expect(data["reporting_line"].map { _1["name"] }).to include("Tunde Bakare")
  end

  it "files a leave request for the token's owner, through the normal workflow" do
    travel_to(Date.new(2026, 10, 2)) do
      data, = tool_result("request_leave", { start_date: "2026-10-12", end_date: "2026-10-16" })

      request = Request.find(data["request_id"])
      expect(request).to have_attributes(requester: person, kind: "leave", status: "pending")
      expect(request.payload).to include("days" => 5, "notice_days" => 10, "start_date" => "2026-10-12", "end_date" => "2026-10-16")
      expect(data["steps"].first).to include("assignee" => "Tunde Bakare")
    end
  end

  it "reports an invalid leave range as a tool error rather than creating anything" do
    _, result = tool_result("request_leave", { start_date: "2026-10-16", end_date: "2026-10-12" })

    expect(result["isError"]).to be(true)
    expect(Request.count).to eq(0)
  end

  it "flags a tool's own error (e.g. an unknown person) as an MCP error result" do
    data, result = tool_result("org_lookup", { person_id: 0 })

    expect(data["error"]).to be_present
    expect(result["isError"]).to be(true)
  end
end
