# One tool call an external MCP client (Claude Desktop, ...) made against
# Keel's /mcp endpoint (SPEC.md section 13) — the trace AGENTS.md rule 3
# asks for, and the "same call arriving" in Keel's own UI. It is not an
# AgentRun on purpose: there is no model call, conversation, answer or
# feedback on Keel's side, and runs feed the agent eval suite and the
# command bar's history, which a client's call has no place in.
class McpCall < ApplicationRecord
  belongs_to :company
  belongs_to :person
  belongs_to :personal_access_token, optional: true

  validates :tool_name, presence: true

  # Saves the call and broadcasts it to its owner's open Settings page.
  def self.record!(person:, token:, tool_name:, input:, output:, is_error:, latency_ms:)
    create!(
      company: person.company, person: person, personal_access_token: token, tool_name: tool_name,
      input: input, output: output, is_error: is_error, latency_ms: latency_ms
    ).tap { McpCallChannel.broadcast_to(person, _1.as_payload) }
  end

  def as_payload
    as_json(only: %i[id tool_name input output is_error latency_ms created_at]).merge("token_name" => personal_access_token&.name)
  end
end
